require 'word_utils'
require 'my_multiset'

module StealEngine
  # TODO: use Logger
  STEAL_DBG = false
  STEAL_PERF_SUMMARY = true

  def self.search(lookup_tree, pool_avail, words_avail, max_steal_len, &word_filter)
    # We convert the pool to a multiset hash i.e. {'a' => 5}, so that if
    # 1 A doesn't work then we don't continue to try 5 A's.
    pool_avail_mshash = MyMultiset.from_array(pool_avail).to_hash
    _search lookup_tree, pool_avail_mshash, words_avail, max_steal_len, &word_filter
  end

  def self._search(lookup_tree, pool_avail_mshash, words_avail, max_steal_len, pool_used=[], words_stolen=[], lv=1, &word_filter)
    print '| '*lv+ "STEALENGINE: Trying #{words_stolen} + #{pool_used} : " if STEAL_DBG

    steal_length = words_stolen.map{|w| w.length}.inject(0, :+)
    return nil, 0 if max_steal_len > 0 and steal_length > max_steal_len

    current_chars = pool_used.join('') + words_stolen.join('')
    candidates, my_cost = lookup_tree.find_superset_str(current_chars, &word_filter)

    puts "Cost #{my_cost}" if STEAL_DBG
    return nil, my_cost unless candidates

    puts '| '*lv+ "           : OK! Remain #{words_avail} + #{pool_avail_mshash}" if STEAL_DBG
    puts '| '*lv+ "           : Some candidates: "+candidates.join(', ') if STEAL_DBG

    until pool_avail_mshash.empty?
      add_pool = pool_avail_mshash.keys.first
      max_num = pool_avail_mshash.delete add_pool
      #add_pool = pool_avail.shift

      (1..max_num).each {|ct|
        res, cost = _search(lookup_tree,
                            pool_avail_mshash.dup,
                            words_avail.dup,
                            max_steal_len,
                            pool_used + [add_pool]*ct,
                            words_stolen,
                            lv + 1,
                            &word_filter)
        my_cost += cost
        return res, my_cost if res
      }
    end

    until words_avail.empty?
      add_steal = words_avail.pop
      #add_steal = words_avail.shift

      res, cost = _search(lookup_tree,
                          pool_avail_mshash.dup,
                          words_avail.dup,
                          max_steal_len,
                          pool_used,
                          words_stolen + [add_steal],
                          lv + 1,
                          &word_filter)
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
