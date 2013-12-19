require 'em-http-request'
require 'em-synchrony'
require 'cancelable_fiber'

require 'log4r-color'

require 'steal_engine'
#require 'steal_engine_brute'
require 'word_matcher'
require 'random_dists'

class StealBot
  include Log4r
  Logger = Log4r::Logger

  ColorOutputter.new 'color', {:colors =>
    {
      :debug  => :dark_gray,
      :info   => :light_blue,
      :warn   => :yellow,
      :error  => :pink,
      :fatal  => {:color => :red, :background => :white}
    }
  }
  #@@log = Logger.new('StealBot', DEBUG)
  @@log = Logger.new('StealBot', INFO)
  @@log.add('color')

  MIN_LEN = 3

  # a reject should take as long as a word of this many chars
  REJECT_EFFECTIVE_CHARS = 9

  def initialize(user_id, lookup_tree, word_ranks, play_token, settings)
    @user_id = user_id
    @lookup_tree = lookup_tree
    @word_ranks = word_ranks
    @play_token = play_token
    @done = false
    self.settings = settings

    @serial = 1
  end

  def settings=(settings)
    @settings = {
      :max_rank => settings['max_rank'] || 0,
      :max_steal_len => settings['max_steal_len'] || 0,
      :max_word_len => settings['max_word_len'] || 0,
      :delay_ms_mean => settings['delay_ms_mean'] || 2000,
      :delay_ms_stdev => settings['delay_ms_stdev'] || 0,
      :delay_ms_per_char => settings['delay_ms_per_char'] || 0,
      :delay_ms_per_kcost => settings['delay_ms_per_kcost'] || 0,
    }
  end

  def ssend(type, data={})
    serial = @serial
    @serial += 1
    msg = {:_t => type, :_s => serial}.merge(data).to_json
    @@log.debug "#{@user_id}: OUT>> #{msg}"
    @http.send msg
  end

  MAX_WORD_LEN_START, MAX_WORD_LEN_STEP, MAX_WORD_LEN_DEFAULT_LIMIT = 4, 2, 15
  MAX_STEAL_LEN_START, MAX_STEAL_LEN_STEP, MAX_STEAL_LEN_DEFAULT_LIMIT = 4, 2, 15
  def got_update(msg)
    return if @done

    stealable = []
    msg['players_order'].each do |p_id|
      stealable += msg['players'][p_id]['words']
    end

    pool = msg['pool']

    if @fiber and @planned_action and @planned_action != :reject
      match_result = WordMatcher.word_match pool, stealable, @planned_action[0]
      @@log.debug "#{@user_id}: planned action #{@planned_action}: #{match_result}"
      if match_result and match_result[0][0] == :ok
        @@log.info "#{@user_id}: planned action #{@planned_action} still valid, continue wait"

        return # exit early, ignoring this update
      else
        @@log.info "#{@user_id}: planned action #{@planned_action} invalidated!"
      end
    end

    res, cost = nil, 0
    start_time = Time.now
    @lookup_tree.clear_cost
    blacklist = Set.new
    max_word_len = MAX_WORD_LEN_START
    max_steal_len = MAX_STEAL_LEN_START
    max_word_len_limit =
      (@settings[:max_word_len] == 0) ? MAX_WORD_LEN_DEFAULT_LIMIT : @settings[:max_word_len]
    max_steal_len_limit =
      (@settings[:max_steal_len] == 0) ? MAX_STEAL_LEN_DEFAULT_LIMIT : @settings[:max_steal_len]
    while true
      word_filter = lambda {|words| words.select {|w|
        next false if w.length < MIN_LEN

        if max_word_len > 0
          next false if w.length > max_word_len
        end

        if @settings[:max_rank] > 0
          next false unless @word_ranks.include? w and
                            @word_ranks[w] <= @settings[:max_rank]
        end

        # Too expensive.
        #t = Time.now
        #match_result = WordMatcher.word_match(pool, stealable, w)
        #t = Time.now - t
        #@@log.error "WM #{w} took #{t}ms"
        #next false unless match_result and match_result[0][0] == :ok
        next false if blacklist.include? w

        next true
      }}

      res, cost = StealEngine.search(
        @lookup_tree,
        pool.shuffle,
        stealable.shuffle,
        @settings[:max_steal_len],
        &word_filter
      )

      if res.nil?
        keep_going = false
        if max_word_len < max_word_len_limit
          max_word_len += MAX_WORD_LEN_STEP
          keep_going = true
        end
        if max_steal_len < max_steal_len_limit
          max_steal_len += MAX_STEAL_LEN_STEP
          keep_going = true
        end

        if keep_going
          next
        else
          break
        end
      end

      match_result = WordMatcher.word_match(pool, stealable, res[0])
      break if match_result[0][0] == :ok

      @@log.debug "StealEngine result #{res} invalid: blacklisting #{res[0]} and trying again"
      blacklist << res[0]
      # loop again
    end

    t = Time.now - start_time

    if res.nil? and @fiber and @planned_action == :reject
      # exit early, let the waiting fiber do it
      return
    end

    @planned_action = res || :reject

    @@log.info "#{@user_id}: Stealengine: #{res || 'nil'} -- took #{t*1000}ms, #{@lookup_tree.accumulated_cost} total cost (== #{cost})"

    @fiber.cancel if @fiber

    @fiber = CancelableFiber.new {
      @@log.info "#{@user_id}: #{stealable} and #{pool}"

      already_paid = Time.now - start_time

      unconditional_delay = RandomDists.gaussian(@settings[:delay_ms_mean], @settings[:delay_ms_stdev])/1000.0
      effective_len = res ? res[0].length : REJECT_EFFECTIVE_CHARS
      char_delay = @settings[:delay_ms_per_char]*effective_len/1000.0
      cost_delay = @settings[:delay_ms_per_kcost]*cost/1000.0/1000.0

      total_delay = unconditional_delay + char_delay + cost_delay
      total_delay = 0 if total_delay < 0

      @@log.info "#{@user_id}: Delays: #{unconditional_delay}s(uncond) + "+
        "#{char_delay}s(char) + #{cost_delay}s(cost) = #{total_delay}s(total)"

      if already_paid < total_delay
        EventMachine::Synchrony.sleep total_delay - already_paid
      end

      if res
        word = res[0]
        @@log.info "#{@user_id}: Claiming #{word}"

        ssend 'claim', {:word => word}

      else
        if msg['pool_remaining'] > 0
          @@log.info "#{@user_id}: Flipping char..."

          ssend 'flip'
        else
          @@log.info "#{@user_id}: Ending game..."

          ssend 'vote_done', {:vote => true}
          @done = true
        end
      end

      @fiber = nil
      @planned_action = nil
    }
    @fiber.resume
  end

  def run
    host = Anathief::AppServer::CONNECT_HOST
    port = Anathief::AppServer::PORT

    @@log.info "#{@user_id}: StealBot starting, connecting to ws://#{host}:#{port}..."

    @http = EventMachine::HttpRequest.new("ws://#{host}:#{port}/websocket").get :timeout => 0
    @http.errback do |e|
      @@log.error "#{@user_id}: StealBot received error: #{e}"
    end
    @http.callback do
      @@log.info "#{@user_id}: Logging in..."
      ssend 'identify', {:id_token => @play_token, :is_robot => true}
    end
    @http.stream do |msg_|
      @@log.debug "#{@user_id}: IN << #{msg_}"

      begin
        msg = JSON.parse(msg_)

        if msg['_t'] == 'update'
          got_update msg
        elsif msg['_t'] == 'restarted'
          @done = false
        end
      rescue StandardError => e
        @@log.error ": (StandardError) #{e.inspect}\n#{e.backtrace.join "\n"}"
      end
    end
    @http.disconnect do
      @@log.info "#{@user_id}: StealBot disconnected."
    end
  end

  def stop
    @@log.info "Stopping bot #{@play_token}"
    if @http
      @fiber.cancel if @fiber
      @http.close_connection
      @http = nil
    end
  end
end
