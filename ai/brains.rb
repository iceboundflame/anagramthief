load 'lookup_tree.rb'
load '../lib/my_multiset.rb'
load '../lib/word_matcher.rb'

puts "Loading #{ARGV[0]} tree"
of = File.new ARGV[0], 'r'
ltr = Marshal.load of
of.close

# TODO: optimization: just use the subsets given by the tree lookup
def steal_engine(ltr, pool_avail, words_avail, pool_used=[], words_stolen=[], lv=1)
  current_chars = pool_used.join('') + words_stolen.join('')

  print '| '*lv+ "STEALENGINE: Trying #{words_stolen} + #{pool_used} : "

  candidates = ltr.find_superset_str(current_chars)
  return false unless candidates

  puts '| '*lv+ "           : OK! Remain #{words_avail} + #{pool_avail}"
  puts '| '*lv+ "           : Some candidates: "+candidates.join(', ')

  until words_avail.empty?
    #add_steal = words_avail.pop
    add_steal = words_avail.shift

    res = steal_engine(ltr,
                       pool_avail.dup,
                       words_avail.dup,
                       pool_used,
                       words_stolen + [add_steal],
                       lv + 1)
    return res if res
  end

  until pool_avail.empty?
    #add_pool = pool_avail.pop
    add_pool = pool_avail.shift

    res = steal_engine(ltr,
                       pool_avail.dup,
                       words_avail.dup,
                       pool_used + [add_pool],
                       words_stolen,
                       lv + 1)
    return res if res
  end

  puts '| '*lv+"End of branch"

  #if (words_stolen.size > 1 or !pool_used.empty?) and
  if (!pool_used.empty?) and
      (normalize_word(current_chars) == normalize_word(candidates[0]))

    puts '| '*lv+"RESULT FOUND! "+candidates[0]
    return [candidates[0], words_stolen, pool_used]
  end

  puts '| '*(lv-1)

  return false
end

#pool_avail = 's'.chars.to_a
##words_avail = ['tile', 'tango', 'turn', 'faeries'] #, 'rifer', 'spile', 'wile']#, 'cameo']
#words_avail = ['tile', 'turn']

pool = 'zxs'.chars.to_a
stealable = ['tiler', 'tango', 'faeries', 'rifer', 'spile', 'wile', 'cameo']

#pool = 'ucohxarilie'.chars.to_a
#stealable = ['five', 'bookie', 'grip', 'gaits', 'clout']

ltr.clear_cost
t = Time.now
res = steal_engine ltr, pool, stealable
t = Time.now - t

puts "Stealengine: #{res}"
puts "#{t*1000}ms"
puts "#{ltr.accumulated_cost} total cost"

#while true
  #print "\n SUBSET> "
  #subset = $stdin.gets
  #if ltr.find_superset_str(subset)
    #puts "FOUND"
  #else
    #puts "no"
  #end
#end
