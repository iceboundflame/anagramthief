
if ARGV.length < 2
  puts "Usage: #{$0} [tree-type] [input]"
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

puts "Letter order: #{lookup_tree.get_letter_order}" if type == 'global_order'
puts "Node count: #{lookup_tree.count_nodes}"
