require 'word_utils'
require 'set'

MIN_LEN = 3

if ARGV.length < 2
  puts "Usage: #{$0} [word-list] [freq-list]"
  exit 1
end

wordfile, freqfile = ARGV[0], ARGV[1]

valid = Set.new

puts "Slurping word file #{wordfile}..."
IO.foreach(wordfile) {|line|
  word = WordUtils.normalize_word_chars line
  next unless word.length >= MIN_LEN
  valid.add word
}

ranked_word_list = []

puts "Slurping freq file #{freqfile}..."
IO.foreach(freqfile) {|line|
  next if line =~ /^\s*#/

  next unless line =~ /^\d+\s+([-A-Za-z]{2,})/
  word = WordUtils.normalize_word_chars $1
  next unless valid.delete word

  ranked_word_list << word
}

puts "Ranked #{ranked_word_list.size} words"
puts "Appending #{valid.size} unranked words"
ranked_word_list.push *valid.to_a

puts "Dumping"
outfile = "#{wordfile}.ranked-#{File.basename freqfile}"
File.open(outfile, 'w') { |of| Marshal.dump ranked_word_list, of }
