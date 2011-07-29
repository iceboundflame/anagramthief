module WordUtils
  def self.word_to_vec(word)
    word = normalize_word word
    vec = []
    a_ord = "a"[0].ord
    (0..25).each {|idx|
      letter = (a_ord + idx).chr
      vec[idx] = word.count(letter)
    }
    return vec
  end

  def self.normalize_word(word)
    return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
  end
end
