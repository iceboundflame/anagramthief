require 'redis'

file = ARGV[0]
rset = ARGV[1]

puts "Reading #{file} => redis set '#{rset}'"
puts "Enter to continue, ^C to abort"
STDIN.gets

@r = Redis.new

i = 0
IO.foreach(file) { |line|
  print '.' if (i += 1) % 1000 == 0
  line.chomp!
  @r.sadd(rset, line)
}
