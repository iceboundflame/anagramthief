require 'word_utils'

module StealEngine
  # TODO: use Logger
  STEAL_DBG = true
  STEAL_PERF_SUMMARY = true

  def self.search(lookup_tree, pool_avail, words_avail)
    _search lookup_tree, pool_avail, words_avail
  end

  # TODO: optimization:
  # Convert pool to a multiset, and don't try the same letter more than once.
  # e.g. if 5 A's in pool, and one A fails, don't try another A.
  def self._search(lookup_tree, pool_avail, words_avail, pool_used=[], words_stolen=[], lv=1)
    print '| '*lv+ "STEALENGINE: Trying #{words_stolen} + #{pool_used} : " if STEAL_DBG

    current_chars = pool_used.join('') + words_stolen.join('')
    candidates, my_cost = lookup_tree.find_superset_str(current_chars)

    puts "Cost #{my_cost}" if STEAL_DBG
    return nil, my_cost unless candidates

    puts '| '*lv+ "           : OK! Remain #{words_avail} + #{pool_avail}" if STEAL_DBG
    puts '| '*lv+ "           : Some candidates: "+candidates.join(', ') if STEAL_DBG

    until pool_avail.empty?
      add_pool = pool_avail.pop
      #add_pool = pool_avail.shift

      res, cost = _search(lookup_tree,
                          pool_avail.dup,
                          words_avail.dup,
                          pool_used + [add_pool],
                          words_stolen,
                          lv + 1)
      my_cost += cost
      return res, my_cost if res
    end

    until words_avail.empty?
      add_steal = words_avail.pop
      #add_steal = words_avail.shift

      res, cost = _search(lookup_tree,
                          pool_avail.dup,
                          words_avail.dup,
                          pool_used,
                          words_stolen + [add_steal],
                          lv + 1)
      my_cost += cost
      return res, my_cost if res
    end

    puts '| '*lv+"End of branch" if STEAL_DBG

    #if (!pool_used.empty?) and # to simulate bug in the old brains
    if (words_stolen.size > 1 or !pool_used.empty?) and
        (WordUtils.normalize_word(current_chars) ==
         WordUtils.normalize_word(candidates[0]))

      puts '| '*lv+"RESULT FOUND! "+candidates[0] if STEAL_DBG
      return [candidates[0], words_stolen, pool_used], my_cost
    end

    puts '| '*(lv-1) if STEAL_DBG

    return nil, my_cost
  end
end
