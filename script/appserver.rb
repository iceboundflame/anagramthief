
ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

require 'eventmachine'
require 'em-websocket'
require 'em-synchrony'
require 'log4r-color'
require 'json'

class ApiError < StandardError
end
class ApiStateError < ApiError
end
class ApiInputError < ApiError
end

class AppServer
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

  class Client
    attr_accessor :ws, :game_id, :user_id

    def conn_id
      ws.object_id
    end

    def initialize(ws)
      @game_id = @user_id = nil
      @ws = ws
    end

    def user_id=(val)
      @user_id = val.to_s
    end

    def identified?
      return !game_id.nil?
    end

    def respond(serial, ok, data={})
      ws.send({
          :_t => 'response',
          :_s => serial,
          :ok => ok
        }.merge(data).to_json)
    end

    def send_message(type, data={})
      ws.send({:_t => type}.merge(data).to_json)
    end
  end

  # N.B. not thread-safe!
  class GameStore
    def initialize
      @games = {}
    end

    # N.B. not thread-safe!
    def find_or_create_game(game_id)
      if @games.include? game_id
        return @games[game_id]
      else
        game = GameState.new game_id
        game.restart
        @games[game_id] = game
        return game
      end
    end

    def get(game_id)
      raise "Game #{game_id} not in store" unless @games.include? game_id
      @games[game_id]
    end
  end


  ### AppServer proper

  def initialize
    @clients = {} # {wsid => {:ws => ws, :game_id => game_id, :user_id => user_id}, ...}
    @game_id_to_clients = {} # {game_id => [client_id, client_id, client_id], ...}
    @store = GameStore.new
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
      :players => game.players.inject({}) {|h,(id,p)|
          h[id] = {
            :id => p.id,
            :name => p.user.name,
            :pf_pic_url => p.user.profile_pic,
            :words => p.words.values.map {|x| x.word}, ## FIXME: sort by ID?
            :score => p.num_letters,
            :is_active => p.is_active,
            :voted_done => p.voted_done,
          }
          h
        },
      :pool => game.pool_seen,
      :pool_remaining => game.num_unseen,
      :is_game_over => game.is_game_over,
      :players_voted_done => game.players_voted_done,
    }
    res[:results] = {
      :ranks => game.compute_ranks.map {|p| {:id => p[:id], :rank => p[:rank]}},
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
    word = msg['word'].upcase.gsub(/[^A-Z]/, '')[0..50] # limit length
    
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
    if game_ending
      game.end_game

      # Compute ranks
      props = Hash.new {|hash, key| hash[key] = []}

      ranks = game.compute_ranks.map { |p|
        { :rank => p[:rank],
          :player => p[:player],
          :num_letters => p[:num_letters] }
      }
    end

    pub_update c.game_id
    pub_action c.game_id, 'voted_done', c.user_id,
      {:vote => vote, :num_voted => num_voted, :num_needed => num_needed,
       :game_ending => game_ending, :ranks => ranks}
    c.respond msg['_s'], true
  end

  def handle_restart(c, game, msg)
    raise ApiStateError, "Game isn't over" unless game.is_game_over

    game.restart
    game.purge_inactive_players

    pub_update c.game_id
    pub_action c.game_id, 'restarted', c.user_id
    c.respond msg['_s'], true
  end

  def handle_chat(c, game, msg)
    utt = msg['message'][0..25] # limit length
    pub_action c.game_id, 'chatted', c.user_id, {:message => utt}
    c.respond msg['_s'], true
  end

  ID_TOKEN_TIMEOUT = (5*60*60) # 5 hours

  def handle_identify(c, msg)
    raise ApiStateError, "Already identified" if c.identified?

    uid, gid, timestamp, verf = msg['id_token'].split(':')

    expected_verf = Digest::SHA1.hexdigest(
      "#{uid}:#{gid}:#{timestamp}:#{Anathief::Application.config.secret_token}")

    raise ApiError, "Bad id_token" if verf != expected_verf

    raise ApiError, "Identification too old, try reloading the page" if
      Time.at(timestamp.to_i) < Time.now - ID_TOKEN_TIMEOUT.second

    c.game_id = gid
    c.user_id = uid

    (@game_id_to_clients[c.game_id] ||= []) << c.conn_id

    game = @store.find_or_create_game c.game_id

    unless game.players.include? c.user_id
      game.add_player c.user_id

      game.load_player_users
    end

    game.player(c.user_id).is_active = true

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
          @clients[ws.object_id] = Client.new(ws)
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

  def update_game_touchstamp(game_id)
    EventMachine.defer {
      @@log.info "Updating game timestamp #{game_id}"
      Game.find(game_id).touch
    }
  end
end


AppServer.new.run Anathief::AppServer::LISTEN_HOST, Anathief::AppServer::PORT
