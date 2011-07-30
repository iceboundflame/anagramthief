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

ranks = {}

puts "Slurping freq file #{freqfile}..."
next_rank = 1
IO.foreach(freqfile) {|line|
  next if line =~ /^\s*#/

  next unless line =~ /^\d+\s+([-A-Za-z]{2,})/
  word = WordUtils.normalize_word_chars $1
  next unless valid.include? word
  next if ranks.include? word

  ranks[word] = next_rank
  next_rank += 1
}

puts "Ranked #{ranks.size} words (== #{next_rank-1})"
puts "Dumping"
outfile = "#{wordfile}.freqs-#{File.basename freqfile}"
File.open(outfile, 'w') { |of| Marshal.dump ranks, of }
