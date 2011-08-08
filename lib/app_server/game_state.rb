require 'word_matcher'
require 'my_multiset'

class AppServer::GameState
  require 'app_server/game_state/player'
  require 'app_server/game_state/word'

  attr_reader :game_id, :is_game_over
  attr_reader :players, :players_order, :pool_unseen, :pool_seen
  attr_reader :is_saved #FIXME this doesn't work yet, need to have children report
  attr_reader :rank_info

  def initialize(game_id=nil)
    @game_id = game_id
    @is_game_over = false
    @players = {}
    @players_order = []
    @pool_unseen = MyMultiset.new
    @pool_seen = []
    @is_saved = false
  end

  def restart
    @is_game_over = false
    @rank_info = nil
    @players.each {|id, p| p.restart}
    @pool_unseen = MyMultiset.from_hash self.class.default_letters
    @pool_seen = []
    @is_saved = false

    flip_char; flip_char; flip_char; flip_char; flip_char; flip_char;
  end

  def player(user_id)
    @players[user_id.to_s]
  end

  def num_active_players
    count = 0
    @players.each {|id, p| count += 1 if p.is_active}
    count
  end

  def num_active_robots
    count = 0
    @players.each {|id, p| count += 1 if p.is_active and p.is_robot}
    count
  end

  def add_player(user_id)
    user_id = user_id.to_s
    return if @players.include? user_id
    @players_order << user_id
    @players[user_id] = Player.new user_id
  end

  def remove_player(user_id)
    return unless @players.include? user_id

    @players.delete user_id
    @players_order.delete(user_id)
    # TODO put back in pool_unseen?
  end

  def purge_inactive_players
    to_remove = @players.keys.select do |id|
      !@players[id].is_active and @players[id].num_letters == 0
    end
    return nil unless to_remove.size > 0

    to_remove.each {|id| remove_player id}
    to_remove
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
      @pool_seen,
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

    p = @players[user_id]
    new_word = p.claim_word word, words_stolen, pool_used

    return :ok, new_word, words_stolen, pool_used
  end


  ### ENDGAME ###

  def num_voted_done
    count = 0
    @players.each {|id, p| count += 1 if p.voted_done}
    count
  end

  def vote_done(user_id, vote)
    @players[user_id].voted_done = vote
  end

  def players_voted_done
    @players.keys.select {|id| @players[id].voted_done}
  end

  def completed?
    return false unless started?
#return true ## FIXME remove this - testing only
    return @pool_unseen.empty? && @pool_seen.size < 15
  end

  def started?
    @pool_unseen.size < MyMultiset.from_hash(self.class.default_letters).size
  end

  def end_game
    unless @is_game_over
      @is_game_over = true

      compute_rank_info
    end
  end

  def compute_stats
    longest_steals = [] # [  [user_id, new_word, [words_stolen]], ...  ]
    word_combines = [] # [  [user_id, new_word, [words_stolen]], ...  ]
    longest_steal_len = 0
    @players.each do |user_id,p|
      p.claims.each do |(word, words_stolen, pool_used_arr)|
        num_ltrs_stolen = words_stolen.inject(0){|ct, word| ct+word.size}
        if num_ltrs_stolen > longest_steal_len
          longest_steals = []
          longest_steal_len = num_ltrs_stolen
        end
        if num_ltrs_stolen > 0 and num_ltrs_stolen == longest_steal_len
          longest_steals << [user_id, word, words_stolen]
        end

        if words_stolen.size > 1
          word_combines << [user_id, word, words_stolen]
        end
      end
    end

    return {
      :longest_steals => longest_steals,
      :word_combines => word_combines,
    }
  end

  def game_record_data
    {
      :game_id => @game_id,
      :completed => completed?,
      :stats_data => compute_stats.to_json,
      :rank_data => @rank_info.to_json,
      :player_data => Hash[
          @players.map {|id,p|
            [id,
              {
                :score => p.num_letters,
                :claims => p.claims,
              }]
          }
        ].to_json,
    }
  end



  protected

  # Returns:
  # [
  #   {:id => id, :score => score, :player => p, :rank => rank},
  #    ...
  # ]
  def compute_rank_info
    rank_data = @players.map do |id, p|
      {:id => id, :score => p.num_letters, :player => p}
    end.sort {|p1,p2| p2[:score] <=> p1[:score]}

    rank = 1
    rank_data.each_with_index do |info, idx|
      if idx > 0 and rank_data[idx-1][:score] != info[:score]
        rank = idx + 1
      end
      info[:rank] = rank
    end

    return @rank_info = rank_data
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


  #def self.redis_key(game_id)
    #"#{Anathief::REDIS_KPREFIX}/game_state/#{game_id}"
  #end
  #def redis_key
    #self.class.redis_key(@game_id)
  #end

  #def self.delete_ids(game_ids)
    #redis_keys = game_ids.map{|id| redis_key id}
    #redis.del *redis_keys
  #end

  #def self.load(game_id)
    #key = redis_key game_id
    #game_json = redis[key]
    #return nil unless game_json
    ##puts "DBG**** gamestate.load: #{game_json}"
    #g = GameState.new.from_json game_json
    #g.is_saved = true
    #g
  #end

  #def save
    #redis[redis_key] = to_json
    #@is_saved = true
  #end

  #def delete
    #redis.del redis_key
    #@is_saved = false
  #end
#


  ### SERIALIZATION ###

  #def from_json(json)
    #from_data(JSON.parse json)
    #self
  #end

  #def to_json
    #to_data.to_json
  #end

  #def to_data
    #{ 'game_id' => @game_id,
      #'is_game_over' => @is_game_over,
      #'players' => @players.map {|id,p| p.to_data},
      #'players_order' => @players_order,
      #'pool_unseen' => @pool_unseen.to_data,
      #'pool_seen' => @pool_seen,
    #}
  #end
  #def self.from_data(x); new.from_data(x); end
  #def from_data(data)
    #@game_id = data['game_id']
    #@is_game_over = data['is_game_over']
    #@players = {}
    #data['players'].each do |pdata|
      #p = Player.from_data pdata
      #@players[p.id] = p
    #end
    #@players_order = data['players_order']
    #@pool_unseen = MyMultiset.from_data data['pool_unseen']
    #@pool_seen = data['pool_seen']

    #self
  #end
