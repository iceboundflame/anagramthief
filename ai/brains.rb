# STATUS: works, but extremely slow
# Too many calls to the LookupTree.
# --dcl 5/12/2011

load 'lookup_tree.rb'
load '../lib/my_multiset.rb'
load '../lib/word_matcher.rb'

puts "Loading #{ARGV[0]} tree"
of = File.new ARGV[0], 'r'
ltr = Marshal.load of
of.close

# TODO: optimization: just use the subsets given by the tree lookup
def steal_engine(ltr, pool, stealable, pool_active=[], stealable_active=[], lv=1)
  all_active = pool_active.join('') + stealable_active.join('')
  candidates = ltr.find_with_subset_str(all_active)
  return false unless candidates

  puts '| '*lv+ "STEALENGINE: Trying #{stealable_active} + pool #{pool_active}"
  puts '| '*lv+ "           : Remain #{stealable} + #{pool}"

  if stealable.empty? and pool.empty?
    puts '| '*lv+"COMPLETE"
    if !pool_active.empty? and normalize_word(all_active) == normalize_word(candidates[0])
      return candidates[0]
    else
      return false
    end
  end

  if stealable.empty?
    # Deplete the pool
    puts '| '*lv+ "pool draw"

    pool.each_index do |pool_idx|
      letter = pool[pool_idx]

      new_pool = pool.dup
      new_pool.delete_at(pool_idx)

      res = steal_engine(ltr, new_pool, stealable, pool_active + [letter], stealable_active, lv+1)
      if res
        return res
      end

      res = steal_engine(ltr, new_pool, stealable, pool_active, stealable_active, lv+1)
      if res
        return res
      end
    end

  else
    puts '| '*lv+ "stealables draw"

    stealable.each_index do |steal_idx|
      steal = stealable[steal_idx]

      new_stealable = stealable.dup
      new_stealable.delete_at(steal_idx)

      # Try adding this steal
      res = steal_engine(ltr, pool, new_stealable, pool_active, stealable_active + [steal], lv+1)
      if res
        return res
      end

      # Try without adding additional steal
      res = steal_engine(ltr, pool, new_stealable, pool_active, stealable_active, lv+1)
      if res
        return res
      end
    end

  end

  return false
end

pool = 'zxs'.chars.to_a
#stealable = ['tiler', 'tango', 'faeries', 'rifer', 'spile', 'wile', 'cameo']
stealable = ['tiler']

res = steal_engine ltr, pool, stealable

puts "Stealengine: #{res}"

#while true
  #print "\n SUBSET> "
  #subset = $stdin.gets
  #if ltr.find_with_subset_str(subset)
    #puts "FOUND"
  #else
    #puts "no"
  #end
#end
