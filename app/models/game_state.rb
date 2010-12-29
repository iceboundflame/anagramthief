require 'word_matcher'
require 'my_multiset'

class GameState
  attr_accessor :game_id
  attr_accessor :players, :players_order, :pool_unseen, :pool_seen
  attr_accessor :is_saved #FIXME this doesn't work yet, need to have children report

  def self.redis_key(game_id)
    "#{Anathief::REDIS_KPREFIX}/game_state/#{game_id}"
  end
  def redis_key
    self.class.redis_key(@game_id)
  end

  def initialize(game_id=nil)
    @game_id = game_id
    @players = {}
    @players_order = []
    @pool_unseen = MyMultiset.new
    @pool_seen = []
    @is_saved = false
  end

  def restart
    @players.each {|id, p| p.restart}
    @pool_unseen = MyMultiset.from_hash self.class.default_letters
    @pool_seen = []
    @is_saved = false
  end

  def self.load(game_id)
    key = redis_key game_id
    game_json = redis[key]
    return nil unless game_json
    #puts "DBG**** gamestate.load: #{game_json}"
    g = GameState.new.from_json game_json
    g.is_saved = true
    g
  end

  def save
    redis[redis_key] = to_json
    @is_saved = true
  end

  def delete
    redis.del redis_key
    @is_saved = false
  end

  def player(user_id)
    @players[user_id.to_s]
  end

  def num_active_players
    count = 0
    @players.each {|id, p| count += 1 if p.is_active}
    count
  end

  def num_voted_restart
    count = 0
    @players.each {|id, p| count += 1 if p.voted_restart}
    count
  end

  def vote_restart(user_id, vote)
    @players[user_id].voted_restart = vote
  end

  def add_player(user_id)
    user_id = user_id.to_s
    return if @players.include? user_id
    @players_order << user_id
    @players[user_id] = Player.new user_id
  end

  def remove_player(user_id)
    return unless @players.include? user_id

    @players.delete id
    @players_order.delete(id)
    # TODO put back in pool_unseen?
  end

  PLAYER_TIMEOUT = 15.seconds

  def update_active_players(active_user_ids)
    now = Time.now
    became_active, became_inactive = [], []
    @players.each {|id,p|
      in_game = active_user_ids.include?(id)
      heart_beatedness =
        p.last_heartbeat && (now - p.last_heartbeat < PLAYER_TIMEOUT)
      is_active = in_game && heart_beatedness
      #puts "Player #{id} was active #{p.is_active} in_game #{in_game} heart #{heart_beatedness}"
      if p.is_active ^ is_active
        #puts "Player #{id} becoming #{is_active}"
        p.is_active = is_active
        if is_active
          became_active << id
        else
          became_inactive << id
        end
      end
    }

    @is_saved = false unless became_active.empty? and became_inactive.empty?
    return became_active, became_inactive
  end

  def purge_inactive_players
    to_remove = @players.keys.select do |id|
      !@players[id].is_active and @players[id].num_letters == 0
    end
    return nil unless to_remove.size > 0

    to_remove.each {|id| remove_player id}
    to_remove
  end

  def load_player_users
    player_ids = @players.map {|id,p| id}
    User.find(player_ids).each do |user|
      @players[user.id_s].user = user
    end
  end

  def flip_char
    return nil if @pool_unseen.empty?

    chosen_letter = @pool_unseen.random_elem
    @pool_unseen.remove chosen_letter
    @pool_seen << chosen_letter

    chosen_letter
  end

  def num_unseen
    @pool_unseen.size
  end

  def claim_word(user_id, word_raw)
    word = word_raw.upcase

    return :word_too_short unless word.length >= 3

    match_result = WordMatcher.word_match(
      MyMultiset.from_array(@pool_seen),
      @players.map {|id,p| p.words.values}.flatten.map {|w| w.word},
      word,
    )
    return :word_not_available unless match_result

    return :word_not_in_dict unless ::WordMatcher.word_in_dict? word

    # [[validity, *validity_data], words_stolen, pool_used]
    return match_result[0][0], *match_result if match_result[0][0] != :ok

    ## Claim is okay, execute it.
    ok, words_stolen, pool_used = match_result

    # FIXME: Fairness: start looking for steals from player after you.
    words_stolen.each do |word|
      @players.each { |id,p| break if p.remove_word word }
    end
    pool_used.each do |letter, count|
      count.times { @pool_seen.delete_at(@pool_seen.index letter) }
    end

    new_word = @players[user_id].add_word word

    return :ok, new_word, words_stolen, pool_used
  end


  def from_json(json)
    from_data(JSON.parse json)
    self
  end

  def to_json
    to_data.to_json
  end

  def to_data
    { 'game_id' => @game_id,
      'players' => @players.map {|id,p| p.to_data},
      'players_order' => @players_order,
      'pool_unseen' => @pool_unseen.to_data,
      'pool_seen' => @pool_seen,
    }
  end
  def self.from_data(x); new.from_data(x); end
  def from_data(data)
    @game_id = data['game_id']
    @players = {}
    data['players'].each do |pdata|
      p = Player.from_data pdata
      @players[p.id] = p
    end
    @players_order = data['players_order']
    @pool_unseen = MyMultiset.from_data data['pool_unseen']
    @pool_seen = data['pool_seen']

    self
  end


  protected

  def self.redis
    @@r ||= Redis.new
  end
  def redis
    @@r ||= Redis.new
  end

  ### UTILITY METHODS ###

  def self.default_letters
    # from http://en.wikipedia.org/wiki/Scrabble_letter_distributions
    { 'E' => 12,
      'A' => 9,
      'I' => 9,
      'O' => 8,
      'N' => 6,
      'R' => 6,
      'T' => 6,
      'L' => 4,
      'S' => 4,
      'U' => 4,
      'D' => 4,
      'G' => 3,
      'B' => 2,
      'C' => 2,
      'M' => 2,
      'P' => 2,
      'F' => 2,
      'H' => 2,
      'V' => 2,
      'W' => 2,
      'Y' => 2,
      'K' => 1,
      'J' => 1,
      'X' => 1,
      'Q' => 1,
      'Z' => 1,
    }
  end
end
