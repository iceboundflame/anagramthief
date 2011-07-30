
if ARGV.length < 2
  puts "Usage: #{$0} [tree-type] [tree-file]"
  exit 1
end

type, infile = ARGV

unless require "lookup_tree/#{type}"
  puts "Invalid tree type #{type}: No such file lookup_tree/#{type}.rb"
  exit 1
end

puts "Loading #{infile}"
lookup_tree = nil
File.open(infile, 'r') {|fh| lookup_tree = Marshal.load fh}

while true
  print "\n SUBSET> "
  subset = $stdin.gets
  res, cost = lookup_tree.find_superset_str(subset)
  if res
    puts "FOUND supersets: #{res}"
  else
    puts "Not found"
  end
  puts "Cost: #{cost}"
end
