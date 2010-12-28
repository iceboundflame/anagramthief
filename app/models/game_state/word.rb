class GameState::Word
  attr_accessor :id, :word

  def initialize(id=nil, word=nil)
    @id = id
    @word = word
  end

  def letters
    @word.chars.to_a
  end

  def to_data
    [@id, @word]
  end
  def self.from_data(x); new.from_data(x); end
  def from_data(data)
    @id, @word = data
    self
  end
end
