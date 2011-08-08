require 'word_utils'
require 'set'

MIN_LEN = 3

if ARGV.length < 3
  puts "Usage: #{$0} [word-list] [freq-list] [max-rank]"
  exit 1
end

wordfile, freqfile, maxrank = ARGV[0], ARGV[1], ARGV[2]
maxrank = maxrank.to_i

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
  next unless valid.include? word
  valid.delete word

  ranked_word_list << word

  break if ranked_word_list.length >= maxrank
}

puts "Got #{ranked_word_list.size} words"

puts "Dumping"
outfile = "#{wordfile}-#{maxrank}-#{File.basename freqfile}"
File.open(outfile, 'w') { |of| ranked_word_list.each {|w| of.puts w} }
