require 'eventmachine'
require 'em-websocket'
require 'em-http-request'
require 'em-synchrony'
require 'log4r-color'
require 'json'
require 'active_support/core_ext/numeric/time'
require 'signed_data'
require 'ordinalize'

class ApiError < StandardError
end
class ApiStateError < ApiError
end
class ApiInputError < ApiError
end

class AppServer
  require 'app_server/game_store'
  require 'app_server/client'
  require 'app_server/game_state'

  include Log4r

  ColorOutputter.new 'color', {:colors =>
    {
      :debug  => :dark_gray,
      :info   => :light_blue,
      :warn   => :yellow,
      :error  => :pink,
      :fatal  => {:color => :red, :background => :white}
    }
  }

  #@@log = Logger.new('app_server', INFO)
  @@log = Logger.new('app_server', DEBUG)
  @@log.add('color')


  ### AppServer proper

  def initialize
    @clients = {} # {wsid => {:ws => ws, :game_id => game_id, :user_id => user_id}, ...}
    @game_id_to_clients = {} # {game_id => [client_id, client_id, client_id], ...}
    @store = AppServer::GameStore.new

    @last_touched = {} # {game_id => Time}
  end

  def pub(game_id, type, data={})
    @game_id_to_clients[game_id].each { |cid|
      @clients[cid].ws.send({:_t => type}.merge(data).to_json)
    }
  end

  def pub_action(game_id, type, from, data={})
    pub game_id, type, {:from => from}.merge(data)
  end

  def pub_update(game_id)
    pub game_id, 'update', generate_update_data(game_id)
  end

  def generate_update_data(game_id)
    game = @store.get(game_id)

    res = {
      :id => game_id,
      #:name => game.name,
      :players_order => game.players_order,
      :players => Hash[ game.players.map {|id,p|
          [id, {
            :id => p.id,
            :name => p.name,
            :pf_pic_url => p.profile_pic,
            :words => p.words.values.map {|x| x.word}, ## FIXME: sort by ID?
            :score => p.num_letters,
            :is_active => p.is_active,
            :is_robot => p.is_robot,
            :voted_done => p.voted_done,
          }]
        }],
      :pool => game.pool_seen,
      :pool_remaining => game.num_unseen,
      :is_game_over => game.is_game_over,
      :players_voted_done => game.players_voted_done,
    }
    res[:results] = {
      :ranks => game.rank_info.map {|p| {:id => p[:id], :rank => p[:rank]}},
      :started => game.started?,
      :completed => game.completed?,
      :stats => game.compute_stats,
    } if game.is_game_over

    res
  end


  ### Request handlers

  def handle_refresh(c, game, msg)
    c.respond msg['_s'], true, {:update_data => generate_update_data}
  end

  TIME_BETWEEN_FLIPS = 0
  #TIME_BETWEEN_FLIPS = 1

  def handle_flip(c, game, msg)
    raise ApiStateError, "Game is over" if game.is_game_over

    last_flip = game.player(c.user_id).last_flip
    if !last_flip || Time.now - last_flip > TIME_BETWEEN_FLIPS.seconds
      char = game.flip_char
      game.player(c.user_id).record_flip

      if char
        pub_update c.game_id
        pub_action c.game_id, 'flipped', c.user_id, {:letter => char}
      else
        raise ApiInputError, 'No more letters to flip.'
      end
    else
      raise ApiInputError, "Wait #{TIME_BETWEEN_FLIPS} seconds between flips."
    end
  end

  def handle_claim(c, game, msg)
    word = msg['word'].upcase.gsub(/[^A-Z]/, '')[0..31] # limit length
    
    raise ApiStateError, "Game is over" if game.is_game_over

    result, *resultdata = game.claim_word(c.user_id, word)

    case result
    when :ok
      new_word, words_stolen, pool_used = resultdata
      pool_used = pool_used.to_a

      pub_update c.game_id
      pub_action c.game_id, 'claimed', c.user_id,
        {:word => word, :words_stolen => words_stolen, :pool_used => pool_used}

      get_defs = proc { get_nice_defs word }
      publish_defs = proc {|defs|
        pub c.game_id, 'definitions', {:defs => defs}
      }
      EventMachine.defer get_defs, publish_defs

      c.respond msg['_s'], true

    when :word_steal_shares_root
      validity_info, words_stolen, pool_used = resultdata
      validity, roots_shared = validity_info
      pool_used = pool_used.to_a
      roots_shared.map! {|w| w.upcase}

      pub_action c.game_id, 'claim_failed', c.user_id,
        {:word => word, :words_stolen => words_stolen, :pool_used => pool_used,
         :cause => result, :shared_roots => roots_shared}
      c.respond msg['_s'], false

    when :word_steal_not_extended, :word_too_short,
         :word_not_in_dict, :word_not_available
      validity_info, words_stolen, pool_used = resultdata
      pool_used = pool_used.to_a

      pub_action c.game_id, 'claim_failed', c.user_id,
        {:word => word, :words_stolen => words_stolen, :pool_used => pool_used,
         :cause => result}
      c.respond msg['_s'], false

    end
  end

  def handle_vote_done(c, game, msg)
    vote = !!msg['vote']

    raise ApiStateError, "Game is over" if game.is_game_over

    game.vote_done c.user_id, vote
    num_voted = game.num_voted_done
    num_needed = game.num_active_players / 2 + 1
    
    game_ending = num_voted >= num_needed
    ranks = nil
    if game_ending
      game.end_game

      record_game game.game_record_data

      # Compute ranks
      props = Hash.new {|hash, key| hash[key] = []}

      ranks = game.rank_info.map {|p| 
        {:id => p[:id], :rank => p[:rank],
          :ordinal => Ordinalize.ordinalize(p[:rank]),
          :name => p[:player].name,
          :score => p[:player].num_letters}}
    end

    pub_update c.game_id
    pub_action c.game_id, 'voted_done', c.user_id,
      {:vote => vote, :num_voted => num_voted, :num_needed => num_needed,
       :game_ending => game_ending, :ranks => ranks, :completed => game.completed?}
    c.respond msg['_s'], true
  end

  def handle_restart(c, game, msg)
    raise ApiStateError, "Game isn't over" unless game.is_game_over

    game.restart
    game.purge_inactive_players

    # Ordered so that bots will see 'restarted' before the first update of the
    # game.
    pub_action c.game_id, 'restarted', c.user_id
    pub_update c.game_id
    c.respond msg['_s'], true
  end

  def handle_chat(c, game, msg)
    utt = msg['message'][0..511] # limit length
    pub_action c.game_id, 'chatted', c.user_id, {:message => utt}
    c.respond msg['_s'], true
  end

  ID_TOKEN_TIMEOUT = (5*60*60) # 5 hours
  MAX_ROBOTS_PER_GAME = 4

  def handle_identify(c, msg)
    raise ApiStateError, "Already identified" if c.identified?

    signed_data = SignedData.decode msg['id_token']

    raise ApiError, "Bad signed_data" unless signed_data

    raise ApiError, "Identification too old, try reloading the page" if
      Time.at(signed_data['timestamp']) < Time.now - ID_TOKEN_TIMEOUT.second

    c.game_id = signed_data['game_id']
    c.user_id = signed_data['user_id']

    game = @store.find_or_create_game c.game_id

    if signed_data['is_robot'] and game.num_active_robots >= MAX_ROBOTS_PER_GAME
      raise ApiError, "Too many robots in this game"
    end

    (@game_id_to_clients[c.game_id] ||= []) << c.conn_id

    unless game.players.include? c.user_id
      game.add_player c.user_id

      #game.load_player_users
    end

    player = game.player c.user_id
    player.is_active = true
    player.is_robot = true if signed_data['is_robot']
    player.name = signed_data['name']
    player.profile_pic = signed_data['profile_pic']

    c.respond msg['_s'], true

    pub_update c.game_id
    pub_action c.game_id, 'joined', c.user_id
  end


  # EM

  def run(host, port)
    EventMachine.synchrony do
      EventMachine::WebSocket.start(:host => host, :port => port) do |ws|
        ws.onopen do
          @@log.info "#{ws.object_id}: connected"
          @clients[ws.object_id] = AppServer::Client.new(ws)
        end

        ws.onmessage do |msg_|
          c = @clients[ws.object_id]
          raise "Unknown connection #{ws.object_id}" if c.nil?

          @@log.debug "#{c.conn_id}: message: #{msg_}"

          begin
            msg = JSON.parse(msg_)

            if msg['_t'] == 'identify'
              handle_identify c, msg

            elsif ['chat', 'refresh','flip','claim','vote_done','restart'].include? msg['_t']

              game = @store.get(c.game_id)

              # Call handle_XYZ
              send "handle_#{msg['_t']}", c, game, msg

              update_game_touchstamp c.game_id

            else
              raise ApiError, "Unknown message type '#{msg['_t']}'"

            end

          rescue ApiError => e
            @@log.warn "#{c.conn_id}: (ApiError) #{e.inspect}\n#{e.backtrace.join "\n"}"
            c.respond msg['_s'], false, {:message => e.to_s}

          rescue StandardError => e
            @@log.error "#{c.conn_id}: (StandardError) #{e.inspect}\n#{e.backtrace.join "\n"}"
            c.respond msg['_s'], false, {:message => "Internal error"}

          end
        end

        ws.onclose do
          @@log.info "#{ws.object_id}: disconnected"

          c = @clients.delete ws.object_id

          if c.identified?
            user_id = c.user_id
            game_id = c.game_id

            @game_id_to_clients[game_id].delete ws.object_id

            unless game_id.nil?
              still_in_room = @game_id_to_clients[game_id].index {|cid|
                @clients[cid].user_id == user_id }

              unless still_in_room
                game = @store.get(game_id)
                game.player(user_id).is_active = false

                # Ordering here is important. Publish 'player left' before
                # purging players, since clients will forget their name
                # otherwise.
                pub_action game_id, 'left', user_id

                game.purge_inactive_players
                pub_update c.game_id
              end
            end
          end
        end

        ws.onerror do |error|
          @@log.error "#{ws.object_id}: SOCKET ERROR: #{error}"
        end
      end

      @@log.info "AppServer started on #{host}:#{port}"
    end
  end


  # Runs asynchronously
  def get_nice_defs(word)
    word.downcase!

    pos_map = {
      'verb-intransitive' => 'verb (used without object)',
      'verb-transitive' => 'verb (used with object)',
    }

    result = Hash.new do |hash, key|
      hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] }
    end

    raw = Wordnik::Word.find(word).definitions
    raw.each do |d|
      next unless d.text
      pos = d.part_of_speech
      if pos_map.include? pos
        pos = pos_map[pos]
      else
        pos.gsub! /-/, ' ' if pos
      end
      result[d.headword][pos] << d.text
    end
    result[word] = [] if result.empty?

    result
  end

  TOUCH_EVERY = 20 #seconds
  def update_game_touchstamp(game_id)
    return if @last_touched.include? game_id and
        Time.now - @last_touched[game_id] < TOUCH_EVERY.seconds
    @last_touched[game_id] = Time.now

    http = EventMachine::HttpRequest.new(Anathief::Internal::ENDPOINT).post({
      :body => { :cmd => 'touch_game', :game_id => game_id }
    })
    http.callback {
      @@log.info "Touched #{game_id} timestamp"
    }
    http.errback {|e|
      @@log.error "Error touching #{game_id} timestamp: #{e}"
    }
  end

  def record_game(data)
    http = EventMachine::HttpRequest.new(Anathief::Internal::ENDPOINT).post({
      :body => { :cmd => 'record_game' }.merge(data)
    })
    http.callback {
      @@log.info "Recorded game data with #{data.to_json}"
    }
    http.errback {|e|
      @@log.error "Error recording game data #{data.to_json}: #{e}"
    }
  end
end
