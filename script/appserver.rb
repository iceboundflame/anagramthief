
ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

require 'eventmachine'
require 'em-websocket'
require 'em-redis'
require 'logger'
require 'json'

puts "Hi."

logger = Logger.new(STDERR)

class Client
  attr_accessor :ws, :game_id, :user_id

  def id
    ws.object_id
  end

  def initialize(ws)
    @game_id = @user_id = nil
    @ws = ws
  end

  def identified?
    return !game_id.nil?
  end

  def respond(status, data)
    ws.send({:status => status}.merge(data).to_json)
  end
end

@clients = {} # {wsid => {:ws => ws, :game_id => game_id, :user_id => user_id}, ...}
@game_id_to_clients = {} # {game_id => [client_id, client_id, client_id], ...}

def pub(game_id, type, data)
  @game_id_to_clients[game_id].each { |cid|
    @clients[cid].ws.send({:type => type}.merge(data).to_json)
  }
end

def pub_action(game_id, type, from, data)
  pub game_id, type, {:from => from}.merge(data)
end

  def load_game
    @state = GameState.load @game_id
    unless @state
      logger.info "Creating GameState #{@game_id}"
      @state = GameState.new @game_id
      @state.restart
    else
      logger.debug "Loaded game: #{@state.to_json}"
    end

    #just_joined = !@state.players.include?(@me_id)
    #@state.add_player(@me_id) if just_joined

    #@state.player(@me_id).beat_heart

    @state.load_player_users
    became_active, became_inactive =
      @state.update_active_players @game.users.map {|u| u.id_s}

    @players = @state.players_order.map{|id| @state.player(id)}

    became_active << @me_id if just_joined
    jpublish_update players_update_json(:added => became_active) unless
      became_active.empty? and became_inactive.empty?
  end

  def save_game
    purged = @state.purge_inactive_players
    #purged = nil
    if purged
      jpublish_update players_update_json(:removed => purged)
    end

    #unless @state.is_saved
      @state.save
      logger.debug 'Saved game: '+@state.to_json
    #end
  end

redis = EM::Protocols::Redis.connect
redis.errback do |code|
  puts "Error code: #{code}"
end

def with_game(game_id, mutable=true)
  key = GameState.redis_key game_id
  EmRedisNxLock.lock key, redis, 10, 5 do |locked| #seconds, retries
    raise "Could not lock game #{game_id}!" unless locked

    redis.get key do |frozen|
      game = GameState.new.from_json frozen
      game.is_saved = true # N.B. i dont think this is fully working yet
      yield game

      #unless game.is_saved
      redis.set key, game.to_json do
        EmRedisNxLock.unlock key, redis #FIXME: need to ensure this runs
      end
      #end
    end
  end
end


EventMachine.run do
  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8123) do |ws|
    ws.onopen do
      logger.info "Connection opened: #{ws.object_id}"
      @clients[ws.object_id] = Client.new(ws)
    end

    ws.onmessage do |msg_|
      c = @clients[ws.object_id]
      logger.debug "Message from #{ws.object_id}: #{msg_}"

      begin
        msg = JSON.parse(msg_)

        if msg['type'] == 'identify'
          raise "Already identified" if c.identified?
          
          c.game_id = msg['game_id']
          c.user_id = msg['user_id']
          # FIXME: security?
          # FIXME: validation

          (@game_id_to_clients[c.game_id] ||= []) << c.id

          pub_action c.game_id, 'join', c.user_id, {}

        elsif msg['type'] == 'chat'
          pub_action c.game_id, 'chat', c.user_id, {:message => msg['message']}

        elsif ['refresh','flip','claim','vote_done','restart'].include? msg['type']

          with_game c.game_id do |game|
            case msg['type']
            when 'refresh'
              #

            when 'flip'
              timeout = 1

              raise "Game is over" if game.is_game_over

              last_flip = game.player(c.user_id).last_flip
              if !last_flip || Time.now - last_flip > timeout.seconds
                char = game.flip_char
                game.player(c.user_id).record_flip

                if char
                  pub_action c.game_id, 'flip', c.user_id, {:letter => char}
                else
                  c.respond false,
                      {:message => "No more letters to flip."}
                end
              else
                c.respond false,
                    {:message => "Wait #{timeout} seconds between flips."}
              end

            when 'claim'
              word = params[:word].upcase.gsub(/[^A-Z]/, '')[0..50] # limit length
              
              raise "Game is over" if game.is_game_over

              #result, *resultdata = @state.claim_word(@me_id, word)

            when 'vote_done'
            when 'restart'
            end
          end

        end

      rescue Exception => e
        logger.warn "#{e.to_s}\n#{e.backtrace.join "\n"}"

        c.respond false, {:message => "Internal error"}
      end
    end

    ws.onclose do
      logger.info "Disconnected: #{ws.object_id}"
      @game_id_to_clients[@clients[ws.object_id].game_id].delete ws.object_id
      @clients.delete ws.object_id
    end

    ws.onerror do |error|
      logger.error "ERROR: #{error}"
    end
  end
end
