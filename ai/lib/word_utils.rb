module WordUtils
  def self.word_to_vec(word)
    word = normalize_word_chars word
    vec = [0]*26

    a_ord = "a"[0].ord
    word.chars.each {|char|
      vec[char.ord - a_ord] += 1
    }
    return vec
  end

  def self.normalize_word_chars(word)
    return word.downcase.gsub(/[^a-z]/, '')
  end

  def self.normalize_word(word)
    return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
  end
end
