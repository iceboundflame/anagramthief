require 'word_utils'
require 'my_multiset'
require 'word_matcher'

module StealEngineBrute
  # TODO: use Logger
  STEAL_DBG = false
  STEAL_PERF_SUMMARY = true

  def self.search(ranked_word_list, pool, stealable, max_steal_len, &word_filter)
    cost = 0
    ranked_word_list.each do |w|
      cost += 1
      #return nil, cost if cost > max_cost
      print "." if cost % 1000 == 0

      match_result = WordMatcher.word_match(pool, stealable, w)
      next unless match_result and match_result[0][0] == :ok

      next if word_filter.call([ w ]).empty?

      return w, cost
    end
  end
end
