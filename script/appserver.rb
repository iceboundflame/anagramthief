
ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

require 'eventmachine'
require 'em-websocket'
require 'em-synchrony'
require 'logger'
require 'json'

$logger = Logger.new(STDERR)

class ApiError < StandardError
end
class ApiStateError < ApiError
end
class ApiInputError < ApiError
end

class AppServer

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

    def respond(status, data={})
      ws.send({:status => status}.merge(data).to_json)
    end

    def send_message(type, data={})
      ws.send({:type => type}.merge(data).to_json)
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
        game = GameState.new @game_id
        game.restart
        @games[game_id] = game
        return game
      end
    end

    def get(game_id)
      raise "#{game_id} not in store" unless @games.include? game_id
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
      @clients[cid].ws.send({:type => type}.merge(data).to_json)
    }
  end

  def pub_action(game_id, type, from, data={})
    pub game_id, type, {:from => from}.merge(data)
  end

  def pub_update(game_id)
    pub game_id, 'update', update_data(game_id)
  end

  def update_data(game_id)
    game = @store.get(game_id)

    players = game.players_order.map {|id| game.player(id)}

    {
      :id => game_id,
      #:name => game.name,
      :players => players.map {|p|
          {
            :id => p.id,
            :name => p.user.name,
            :pf_pic_url => p.user.profile_pic,
            :words => p.words.values.map {|x| x.word}, ## FIXME: sort by ID?
            :score => p.num_letters,
            :is_active => p.is_active,
            :voted_done => p.voted_done,
          }
        },
      :pool => game.pool_seen,
      :pool_remaining => game.num_unseen
    }
  end


  ### Request handlers

  def handle_refresh(c, game, msg)
    raise 'unimpl'
  end

  def handle_flip(c, game, msg)
    timeout = 1

    raise ApiStateError, "Game is over" if game.is_game_over

    last_flip = game.player(c.user_id).last_flip
    if !last_flip || Time.now - last_flip > timeout.seconds
      char = game.flip_char
      game.player(c.user_id).record_flip

      if char
        pub_update c.game_id
        pub_action c.game_id, 'flip', c.user_id, {:letter => char}
      else
        c.respond false,
            {:message => "No more letters to flip."}
      end
    else
      c.respond false,
          {:message => "Wait #{timeout} seconds between flips."}
    end
  end

  def handle_claim(c, game, msg)
    word = msg['word'].upcase.gsub(/[^A-Z]/, '')[0..50] # limit length
    
    raise ApiStateError, "Game is over" if game.is_game_over

    result, *resultdata = game.claim_word(c.user_id, word)

    case result
    when :ok
      new_word, words_stolen, pool_used = resultdata

      pub_update c.game_id
      pub_action c.game_id, 'claimed', c.user_id,
        {:word => word, :words_stolen => words_stolen, :pool_used => pool_used}

      #jpublish_update pool_update_json,
        #players_update_json(:new_word_id => [@me_id, new_word.id])

      # do this as late as possible so it doesn't matter if this API
      # hangs/takes a long time
      lookup_and_publish_definitions(word)

      c.respond true

    when :word_steal_shares_root
      validity_info, words_stolen, pool_used = resultdata
      validity, roots_shared = validity_info

      pub_action c.game_id, 'claim_fail', c.user_id,
        {:word => word, :words_stolen => words_stolen, :pool_used => pool_used,
         :cause => result, :shared_roots => roots_shared}
      c.respond false

    when :word_steal_not_extended , :word_too_short ,
         :word_not_in_dict , :word_not_available
      validity_info, words_stolen, pool_used = resultdata

      pub_action c.game_id, 'claim_fail', c.user_id,
        {:word => word, :words_stolen => words_stolen,
         :cause => result}
      c.respond false

    end
  end

  def handle_vote_done(c, game, msg)
    vote = (msg['vote'] != 'false')

    if game.is_game_over
      c.respond false
      return
    end

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
    pub_action c.game_id, 'vote_done', c.user_id,
      {:vote => vote, :num_voted => num_voted, :num_needed => num_needed,
       :game_ending => game_ending, :ranks => ranks}
    c.respond true
  end

  def handle_restart(c, game, msg)
    if game.is_game_over
      c.respond false
      return
    end

    game.restart

    pub_update c.game_id
    pub_action c.game_id, 'restarted', c.user_id
    c.respond true
  end

  def handle_chat(c, game, msg)
    pub_action c.game_id, 'chat', c.user_id, {:message => msg['message']}
    c.respond true
  end

  def handle_identify(c, msg)
    raise ApiStateError, "Already identified" if c.identified?

    c.game_id = msg['game_id']
    c.user_id = msg['user_id']
    # FIXME: security?
    # FIXME: validation

    (@game_id_to_clients[c.game_id] ||= []) << c.conn_id

    game = @store.find_or_create_game c.game_id

    unless game.players.include? c.user_id
      game.add_player c.user_id

      game.load_player_users
    end

    game.player(c.user_id).is_active = true

    pub_update c.game_id
    pub_action c.game_id, 'join', c.user_id
    c.respond true
  end


  # EM

  def run
    $logger.info "AppServer starting"

    EventMachine.synchrony do
      EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8123) do |ws|
        ws.onopen do
          $logger.info "Connection opened: #{ws.object_id}"
          @clients[ws.object_id] = Client.new(ws)
        end

        ws.onmessage do |msg_|
          c = @clients[ws.object_id]
          raise "Unknown connection #{ws.object_id}" if c.nil?

          $logger.debug "Message from #{c.conn_id}: #{msg_}"

          begin
            msg = JSON.parse(msg_)

            if msg['type'] == 'identify'
              handle_identify c, msg

            elsif ['chat', 'refresh','flip','claim','vote_done','restart'].include? msg['type']

              game = @store.get(c.game_id)

              # Call handle_XYZ
              send "handle_#{msg['type']}", c, game, msg

            else
              raise ApiError, "Unknown message type '#{msg['type']}'"

            end

          rescue ApiError => e
            $logger.warn "#{c.conn_id}: #{e.to_s}\n#{e.backtrace.join "\n"}"
            c.respond false, {:message => e.to_s}

          rescue StandardError => e
            $logger.warn "#{c.conn_id}: #{e.to_s}\n#{e.backtrace.join "\n"}"
            c.respond false, {:message => "Internal error"}

          end
        end

        ws.onclose do
          $logger.info "Disconnected: #{ws.object_id}"

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

                #TODO: purge inactive players with no pieces

                pub_update c.game_id
                pub_action game_id, 'leave', user_id
              end
            end
          end
        end

        ws.onerror do |error|
          $logger.error "ERROR: #{error}"
        end
      end
    end
  end









  def lookup_and_publish_definitions(word)
    definitions = get_nice_defs word
    #$logger.debug green PP.pp definitions, ''
    pub 'definitions', definitions
  end

  ### below code could be moved out

  def get_nice_defs(word)
    return [] # XXX: remove me

    word.downcase!

    pos_map = {
      'verb-intransitive' => 'verb (used without object)',
      'verb-transitive' => 'verb (used with object)',
    }

    result = Hash.new do |hash, key|
      hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] }
    end

    ### FIXME: do this asynchronously so as not to block all users

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

end

AppServer.new.run
