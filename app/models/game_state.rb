class GameState
  attr_accessor :game_id
  attr_accessor :players, :players_order, :pool_unseen, :pool_seen
  attr_accessor :saved

  def self.redis_key(game_id)
    "anathief/game_state/#{game_id}"
  end
  def redis_key
    self.class.redis_key(@game_id)
  end

  def self.load(game_id)
    key = redis_key game_id
    game_json = redis[key]
    return nil unless game_json
    g = GameState.new.from_json game_json
    g.saved = true
    g
  end

  def initialize(game_id=nil,
                 players={}, players_order=[],
                 pool_unseen=nil, pool_seen=[])
    @game_id = game_id
    @players = players
    @players_order = players_order
    @pool_unseen = pool_unseen || self.class.default_letters
    @pool_seen = pool_seen
  end

  def restart
    @players.each do |id, p|
      p['words'] = []
      p['score'] = 0
      p['voted_restart'] = false
    end
    @pool_unseen = self.class.default_letters
    @pool_seen = []
    @saved = false
  end

  def from_json(json)
    data = JSON.parse json

    @game_id = data['game_id']
    @players = data['players']
    @players_order = data['players_order']
    @pool_unseen = data['pool_unseen']
    @pool_seen = data['pool_seen']

    recompute_scores
    self
  end

  def to_json
    {
      :game_id => @game_id,
      :players => @players,
      :players_order => @players_order,
      :pool_unseen => @pool_unseen,
      :pool_seen => @pool_seen,
    }.to_json
  end

  def save
    redis[redis_key] = to_json
    @saved = true
  end

  def delete
    redis.del redis_key
    @saved = false
  end

  def player(user_id)
    @players[user_id.to_s]
  end

  def num_voted_to_restart
    count = 0
    @players.each do |id, p|
      count += 1 if p.fetch('voted_restart', false)
    end
    count
  end
  def vote_restart(user_id, vote)
    @players[user_id]['voted_restart'] = vote
  end


  def add_player(user_id)
    user_id = user_id.to_s
    return if @players.has_key? user_id
    @players_order << user_id
    @players[user_id] = { 'words' => [], 'id' => user_id, 'score' => 0 }
  end

  def update_active_players(active_user_ids)
    @players.each do |id,p|
      p['active'] = active_user_ids.include? id
    end
  end

  def purge_inactive_players
    user_id = user_id.to_s

    to_remove = @players.keys.select do |id|
      !@players[id]['active'] and @players[id]['words'].size == 0
    end
    return nil unless to_remove.size > 0

    to_remove.each do |id|
      @players.delete id
      @players_order.delete(id)
    end
    to_remove
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
    multiset_size @pool_unseen
  end

  def remove_player(user_id)
    return unless @players.has_key? user_id

    # TODO put back in pool_seen?
  end

  def claim_word(user_id, word_raw)
    word = word_raw.upcase

    # TODO: word cannot have same root
    return :word_too_short unless word.length >= 3
    return :word_not_in_dict unless word_in_dict? word

    words_stolen, pool_used = word_match(
      letters_to_multiset(@pool_seen),
      @players.map {|id,p| p['words']}.flatten,
      word,
    )

    return :word_not_available unless words_stolen

    return :word_not_extended if
      words_stolen.size == 1 and multiset_size(pool_used) == 0
    #FIXME: check other possiblities: pool, or combine two other words

    words_stolen.each do |word|
      @players.each do |id,p|
        idx = p['words'].index word
        if idx
          p['words'].delete_at(idx)
          break
        end
      end
    end
    pool_used.each do |letter, count|
      count.times { @pool_seen.delete_at(@pool_seen.index letter) }
    end

    @players[user_id]['words'] << word

    recompute_scores
    return :ok, words_stolen, pool_used
  end

  def recompute_scores
    @players.each do |id, player|
      player['score'] = player['words'].inject(0) {|sum, word| sum+word.length}
    end
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

  def word_in_dict?(word_raw)
    word = word_raw.upcase
    redis.sismember('twl06', word)
  end

  def multiset_diff(a_in, b_in)
    a = a_in.clone
    b = b_in.clone
    (a.keys | b.keys).each do |k|
      acount = a.fetch(k, 0) - b.fetch(k, 0)
      if acount > 0
        a[k] = acount
      elsif acount < 0
        b[k] = -acount
      end
      a.delete(k) if acount <= 0
      b.delete(k) if acount >= 0
    end

    return a, b
  end

  def multiset_size(a)
    a.values.inject(0) {|sum, ct| sum + ct}
  end

  def word_to_multiset(word)
    letters_to_multiset word.chars.to_a
  end

  def letters_to_multiset(letters)
    result = {}
    letters.each do |letter|
      result[letter] = result.fetch(letter, 0) + 1
    end
    result
  end

  def word_match(pool_ms, words, target)
    words_used = []
    target_ms = word_to_multiset(target)
    words.each_index do |word_idx|
      word = words[word_idx]
      leftover_ms, deficit_ms = multiset_diff(word_to_multiset(word), target_ms)
      if multiset_size(leftover_ms) == 0
        words_used << word
        target_ms = deficit_ms
      end
    end

    leftover_ms, deficit_ms = multiset_diff(pool_ms, target_ms)
    return words_used, target_ms if multiset_size(deficit_ms) == 0
    return nil
  end
end
