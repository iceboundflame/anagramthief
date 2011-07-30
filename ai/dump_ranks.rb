
if ARGV.length < 1
  puts "Usage: #{$0} [freq-list] [max-rank=30000]"
  exit 1
end

freq_file, max_rank = ARGV
max_rank ||= 30000
max_rank = max_rank.to_i

ranks = nil

puts "Loading #{freq_file} freqs"
File.open(freq_file, 'r') {|fh| ranks = Marshal.load fh}

ranks = ranks.invert
ranks.keys.sort.each {|r|
  puts "#{r}: #{ranks[r]}"
}
