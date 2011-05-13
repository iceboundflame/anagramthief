load 'lookup_tree.rb'

def normalize_word(word)
  return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
end

@anagrams = Hash.new {|hash, key| hash[key] = []}

ltr = LookupTree.new

if false
  #words = ['doog']
  #words = ['dog', 'sit', 'goads', 'simplification', 'soa']
  #words = ['dog', 'goads', 'sit'] # FAILS THIS CASE! no 's' node

  words = "When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split

  words.each {|x|
    puts "\nADDING: #{x}"
    ltr.find(x, true)
    puts "\nRESULT:"
    ltr.print
  }

  while true
    print "\n SUBSET >"
    subset = gets
    if ltr.find_with_subset_str(subset)
      puts "FOUND"
    else
      puts "no"
    end
  end
end

begin
  file = ARGV[0]
  i = 0
  IO.foreach(file) { |line|
    i += 1
    line.chomp!
    ltr.find(line.downcase, true)

    if i % 100 == 0
      puts "[n=#{i}] #{line}"
    end
  }
rescue Interrupt
end

puts "Dumping"
outf = ARGV[0] + ".t2"
of = File.new outf, 'w'
Marshal.dump ltr, of
of.close

#dump_tree (tree)
#tree_stat(tree)

#puts MyMultiset.from_letters("helloworldthere").to_letters
