class GameState
  attr_accessor :game_id
  attr_accessor :players, :pool_unseen, :pool_seen

  def self.redis_key(game_id)
    "anathief/gamestate/#{game_id}"
  end
  def redis_key
    self.class.redis_key(@game_id)
  end

  def self.load_from_redis(game_id)
    key = redis_key game_id
    game_json = redis[key]
    if game_json
      new.from_json game_json
    else
      new game_id
    end
  end

  def initialize(game_id=nil, players={}, pool_unseen=nil, pool_seen=[])
    @game_id = game_id
    @players = players
    @pool_unseen = pool_unseen || self.class.default_letters
    @pool_seen = pool_seen
  end

  def from_json(json)
    data = JSON.parse json

    @game_id = data['game_id']
    @players = data['players']
    @pool_unseen = data['pool_unseen']
    @pool_seen = data['pool_seen']
    self
  end

  def to_json
    {
      :game_id => @game_id,
      :players => @players,
      :pool_unseen => @pool_unseen,
      :pool_seen => @pool_seen
    }.to_json
  end

  def save_to_redis
    redis[redis_key] = to_json
  end

  def destroy
    redis.del redis_key
  end

  def player(user_id)
    @players[user_id.to_s]
  end

  def add_player(user_id)
    user_id = user_id.to_s
    return if @players.has_key? user_id
    @players[user_id] = { 'words' => [], 'id' => user_id }
  end

  def flip_char
    return nil if @pool_unseen.empty?

    letters = @pool_unseen.keys
    running_ct = 0
    cdf = letters.map { |ltr| running_ct += @pool_unseen[ltr]; running_ct }

    randValue = rand
    chosen_letter = nil
    cdf.size.times do |idx|
      if randValue <= cdf[idx].to_f/running_ct
        chosen_letter = letters[idx]
        break
      end
    end

    @pool_unseen[chosen_letter] -= 1
    @pool_unseen.delete(chosen_letter) unless @pool_unseen[chosen_letter] > 0
    @pool_seen << chosen_letter

    chosen_letter
  end

  def num_unseen
    @pool_unseen.inject(0) {|sum, (letter, ct)| sum + ct}
  end

  def remove_player(user_id)
    return unless @players.has_key? user_id

    # TODO put back in pool_seen?
  end

  def claim_word(user_id, word)
    word.upcase!

    # TODO: validate word in dictionary
    # TODO: word cannot have same root
    # TODO: check other player's words

    ok = true
    new_pool_seen = @pool_seen
    word.each_char { |ch|
      if idx = new_pool_seen.index(ch)
        new_pool_seen.delete_at idx
      else
        ok = false
        break
      end
    }

    if ok
      @pool_seen = new_pool_seen
      @players[user_id]['words'] << word
    end

    ok
  end

  def saved?
    return @saved
  end

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

  protected
  def self.redis
    @r ||= Redis.new
  end
  def redis
    @@r ||= Redis.new
  end
end
