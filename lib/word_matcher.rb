require 'set'
require 'redis'

module WordMatcher
  @redis = Redis.new
  
  def self.word_in_dict?(word_raw)
    word = word_raw.upcase
    @redis.sismember('twl06', word)
  end

  def self.lookup_shared_roots(word1, word2s)
    args = '2+2lemma', word1.downcase, *word2s.map {|w| w.downcase}
    roots = @redis.hmget(*args)
    if roots
      root1_str = roots.delete_at(0)
      return nil unless root1_str
      roots1 = Set.new(root1_str.split ',')

      roots.each do |root2_str|
        next unless root2_str
        roots2 = Set.new(root2_str.split ',')

        roots_shared = roots1 & roots2
        return roots_shared.to_a if roots_shared.size > 0
      end
    end
    nil
  end

  def self.validate_match(target, stolen, pool_used)
    return [:word_steal_not_extended] if
      stolen.size == 1 and pool_used.size == 0

    roots_shared = lookup_shared_roots target, stolen
    return [:word_steal_shares_root, roots_shared] if
      stolen.size == 1 and roots_shared

    return [:ok]
  end

  def self.test_wm(pools, stealable, target)
    word_match pools.chars.to_a,stealable,target, nil, [], 1, true
  end

  #
  # Returns: [[validity, *validity_data], stolen, pool_used]
  #
  # FIXME: Fairness: start looking for steals from player after you.
  def self.word_match(pool, stealable, target,
                      need_ms=nil, stolen=[],
                      depth=1, dbg=false)

    need_ms = MyMultiset.from_letters(target) unless need_ms
    raise ArgumentError, 'pool should be Array' unless pool.kind_of?(Array)
    raise ArgumentError, 'stealable should be Array' unless stealable.kind_of?(Array)
    raise ArgumentError, 'target should be String' unless target.kind_of?(String)
    raise ArgumentError, 'need_ms should be MyMultiset' unless need_ms.kind_of?(MyMultiset)

    ind = '  '*depth
    if dbg
      puts "\n#{ind}*** Word Match: need:#{need_ms.to_a}"
      puts "#{ind}Stolen: #{stolen}"
      puts "#{ind}Avail: #{stealable}"
      puts "#{ind}Pool: #{pool}"
    end

    best_match = nil
    if need_ms.size > 0
      ## Recursively try to steal

      stealable.each_index do |word_idx|
        word = stealable[word_idx]
        leftover_ms, deficit_ms = MyMultiset.from_letters(word) ^ need_ms
        if leftover_ms.size == 0 # can use whole word
          puts "#{ind}--#{word} means we're still short #{deficit_ms.to_a}" if dbg

          remaining_words = stealable.last(stealable.size - (word_idx+1))
          new_stolen = stolen.dup << word
          match_result = word_match(pool, remaining_words,
                                    target, deficit_ms, new_stolen,
                                    depth+1, dbg)

          #puts "#{ind}=>#{match_result}" if dbg and match_result
          return match_result if match_result and match_result[0][0] == :ok
          best_match = match_result unless best_match
        end
      end
    end

    ## Check the pool

    leftover_ms, deficit_ms = MyMultiset.from_array(pool) ^ need_ms
    if dbg
      puts "#{ind}=> pool = #{MyMultiset.from_array(pool)}"
      puts "#{ind}=> need = #{need_ms}"
      puts "#{ind}=> pool - need = #{leftover_ms}, #{deficit_ms}"
    end

    if deficit_ms.size == 0
      pool_used_ms = need_ms
      validity_arr = validate_match target, stolen, pool_used_ms

      result = validity_arr, stolen, pool_used_ms
      puts "#{ind}=> Using pool: #{result}\n\n" if dbg
      return result if deficit_ms.size == 0
    else
      if dbg
        if best_match
          puts "#{ind}=> Returning best match #{best_match}\n\n"
        else
          puts "#{ind}=> Dead end\n\n"
        end
      end
      return best_match
    end
  end
end
