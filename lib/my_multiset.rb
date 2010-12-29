class MyMultiset
  def initialize(args={})
    @hash = {}
    if args.include? :word
      from_letters args[:word]
    elsif args.include? :array
      from_array args[:array]
    elsif args.include? :hash
      from_hash args[:hash]
    end
  end

  # Sugar
  def self.from_letters(x); new.from_letters(x); end
  def self.from_array(x); new.from_array(x); end
  def self.from_hash(x); new.from_hash(x); end

  def from_letters(word)
    from_array word.chars.to_a
  end
  def from_array(array)
    @hash = {}
    array.each do |letter|
      @hash[letter] = @hash.fetch(letter, 0) + 1
    end
    self
  end
  def from_hash(hash)
    @hash = hash.dup
    self
  end

  def to_a
    res = []
    @hash.each do |ltr, ct|
      res += [ltr] * ct
    end
    res
  end

  def to_hash
    @hash.dup
  end

  def to_s
    "#Multiset"+@hash.to_s
  end

  def size
    @hash.values.inject(0) {|sum, ct| sum + ct}
  end

  def empty?
    @hash.empty? || size == 0
  end

  def ^(second)
    a = @hash.dup
    b = second.hash.dup
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

    #return MyMultiset.from_hash(a), MyMultiset.from_hash(b)
    return self.class.from_hash(a), self.class.from_hash(b)
  end

  def each
    hash.each { |id, ct| yield id, ct }
  end

  def keys
    hash.keys
  end

  def [](key)
    hash[key]
  end

  # Weighted random selection
  def random_elem
    letters = @hash.keys
    running_ct = 0
    cdf = letters.map { |ltr| running_ct += @hash[ltr]; running_ct }
    return nil if running_ct == 0

    randValue = rand
    cdf.size.times do |idx|
      return letters[idx] if randValue <= cdf[idx].to_f/running_ct
    end
    return nil
  end

  def remove(elem, n=1)
    return remove_all elem if n < 0
    return unless @hash.include? elem
    remain = (@hash[elem] -= n)
    @hash.delete elem if remain <= 0
  end
  def remove_all(elem)
    @hash.delete elem
  end

  def to_data
    @hash
  end

  def self.from_data(x); new.from_data(x); end
  def from_data(data)
    @hash = data
    self
  end

  protected
  attr_accessor :hash
end
