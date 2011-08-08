class AppServer::GameState::Player
  attr_accessor :id, :words, :voted_done, :next_word_id,
    :is_active, :last_heartbeat, :claims, :last_flip
  attr_accessor :user
  attr_accessor :is_robot

  attr_accessor :name, :profile_pic

  def initialize(id=nil)
    @id = id
    @words = {}
    @voted_done = false
    @next_word_id = 1
    @is_active = false
    @is_robot = false
    @last_heartbeat = nil
    @claims = []
    @user = nil

    @name = nil
    @profile_pic = nil
  end

  def restart
    @words = {}
    @voted_done = false
    @next_word_id = 1
    @claims = []
  end

  def voted_done?
    @voted_done
  end

  def record_flip
    @last_flip = Time.now
  end

  def beat_heart
    @last_heartbeat = Time.now
  end

  def num_letters
    @words.inject(0) {|sum, (id,w)| sum + w.word.length}
  end

  def add_word(word)
    w = AppServer::GameState::Word.new(@next_word_id, word)
    @words[@next_word_id] = w
    @next_word_id += 1
    w
  end

  def claim_word(word, words_stolen, pool_used)
    @claims << [word, words_stolen, pool_used.to_array]
    return add_word word
  end

  def remove_word_id(id)
    @words.delete(id)
  end
  def remove_word(word)
    w = find_word(word)
    return nil unless w
    remove_word_id(w.id)
    true
  end
  def find_word(word)
    @words.each do |id, w|
      return w if w.word == word
    end
    nil
  end

  def to_data
    { 'id' => @id,
      'words' => @words.map {|id,w| w.to_data},
      'voted_done' => @voted_done,
      'next_word_id' => @next_word_id,
      'is_active' => @is_active,
      'last_heartbeat' => @last_heartbeat,
      'last_flip' => @last_flip,
      'claims' => @claims,
    }
  end
  def self.from_data(x); new.from_data(x); end
  def from_data(data)
    @id = data['id']
    @words = {}
    data['words'].map {|wdata|
      w = GameState::Word.from_data wdata
      @words[w.id] = w
    }
    @voted_done = data['voted_done']
    @next_word_id = data['next_word_id']
    @is_active = data['is_active']
    @last_heartbeat = data['last_heartbeat']
    @last_heartbeat &&= Time.parse @last_heartbeat
    @last_flip = data['last_flip']
    @last_flip &&= Time.parse @last_flip
    @claims = data['claims'] || []
    self
  end
end
