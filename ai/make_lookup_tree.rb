require 'word_utils'
require 'active_support/inflector'

if ARGV.length < 2
  puts "Usage: #{$0} [tree-type] [input]"
  exit 1
end

type, infile = ARGV

unless require "lookup_tree/#{type}"
  puts "Invalid tree type #{type}: No such file lookup_tree/#{type}.rb"
  exit 1
end

if false
  #words = ['doog']
  #words = ['dog', 'sit', 'goads', 'simplification', 'soa']
  #words = ['dog', 'goads', 'sit'] # FAILS THIS CASE! no 's' node

  words = "When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split

  words.each {|x|
    puts "\nADDING: #{x}"
    lookup_tree.find(x, true)
    puts "\nRESULT:"
    lookup_tree.print
  }

  while true
    print "\n SUBSET >"
    subset = gets
    if lookup_tree.find_with_subset_str(subset)
      puts "FOUND"
    else
      puts "no"
    end
  end
end

lookup_tree = "LookupTree::#{type.camelize}".constantize.new

puts "Slurping file..."
words = []
IO.foreach(infile) {|line|
  word = line.chomp
  word.downcase!
  words << word
}

begin
  #lookup_tree.build words, {:progress => true}
  lookup_tree.build words, {:progress => true, :alpha_order => true}
rescue Interrupt
end

puts "Dumping"
outfile = "#{infile}.#{lookup_tree.describe}.t2"
File.open(outfile, 'w') { |of| Marshal.dump lookup_tree, of }

puts "Letter order: #{lookup_tree.get_letter_order}"
puts "Node count: #{lookup_tree.count_nodes}"
#dump_tree (tree)
#tree_stat(tree)
