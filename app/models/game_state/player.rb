class GameState::Player
  attr_accessor :id, :words, :voted_restart, :next_word_id, :is_active
  attr_accessor :user

  def initialize(id=nil)
    @id = id
    @words = {}
    @voted_restart = false
    @next_word_id = 1
    @is_active = false
    @user = nil
  end

  def restart
    @words = {}
    @voted_restart = false
    @next_word_id = 1
  end

  def voted_restart?
    @voted_restart
  end

  def num_letters
    @words.inject(0) {|sum, (id,w)| sum + w.word.length}
  end

  def add_word(word)
    @words[@next_word_id] = GameState::Word.new(@next_word_id, word)
    @next_word_id += 1
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
      return w if (w.word == word)
    end
  end

  def to_data
    { 'id' => @id,
      'words' => @words.map {|id,w| w.to_data},
      'voted_restart' => @voted_restart,
      'next_word_id' => @next_word_id,
      'is_active' => @is_active,
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
    @voted_restart = data['voted_restart']
    @next_word_id = data['next_word_id']
    self
  end
end
