require 'word_utils'

# Possible improvement:
# Can also change the order per-branch by storing the next letter in each
# node.
#
# http://blog.notdot.net/2007/10/Damn-Cool-Algorithms-Part-3-Anagram-Trees
# http://blog.notdot.net/2007/10/Update-on-Anagram-Trees

module LookupTree
  class SmartBranch
    attr_accessor :accumulated_cost

    def initialize
      clear_cost
      @root = []
    end

    def clear_cost
      @accumulated_cost = 0
    end

    FIND_SUBSET_DBG = false
    FIND_DBG = false

    @show_progress = false

    def build(words, opts={})
      @show_progress = !!opts[:progress]
      puts "Vectorizing words..." if @show_progress

      all_word_vecs = {}
      words.each {|w| all_word_vecs[w] = WordUtils.word_to_vec(w)}

      puts "Building tree..." if @show_progress
      @root = _build(words, all_word_vecs, (0..25).to_a)
    end
    def _build(words_left, all_word_vecs, symbols_left, level = 1)
      if symbols_left.empty?
        return words_left
      end

      print_ok = @show_progress && words_left.size > 1000

      puts "| "*level + "#{words_left.size} words left" if print_ok

      symbol_idx, words_in_branches =
        _branch_words_minimally(words_left, all_word_vecs, symbols_left)

      puts "| "*level + "Branching on #{(symbol_idx+'a'.ord).chr}" if print_ok

      children = []
      words_in_branches.each_index {|ct|
        puts "| "*level + "=== #{ct} #{(symbol_idx+'a'.ord).chr}'s" if print_ok
        next if words_in_branches[ct].nil?

        new_symbols_left = symbols_left.dup
        new_symbols_left.delete symbol_idx
        children[ct] = _build(words_in_branches[ct], all_word_vecs, new_symbols_left, level+1)
      }

      return [symbol_idx, children]
    end

    # Find symbol with least number of unique frequencies among the words
    # given. Then subdivides the words by these frequencies.
    #
    # Returns: [symbol_idx, words_in_branches]
    # where words_in_branches[i] is an array of word strings that have i
    # number of symbol symbol_idx
    def _branch_words_minimally(words, all_word_vecs, candidate_symbols)
      symbol_counts = [0]*26
      words.each {|w|
        w_vec = all_word_vecs[w]
        w_vec.each_index { |i|
          symbol_counts[i] = [symbol_counts[i], w_vec[i]].max
        }
      }

      # Least common symbol first
      symbol_idx = candidate_symbols.min_by {|x| symbol_counts[x]}

      branches = []
      words.each {|w|
        w_count = all_word_vecs[w][symbol_idx]
        branches[w_count] ||= []
        branches[w_count] << w
      }

      return [symbol_idx, branches]
    end

    def find(word)
      vec = WordUtils.word_to_vec word
      puts word +" => "+ vec.to_s if FIND_DBG

      node = @root
      (0..25).each {|level|
        symbol_idx, children = node
        puts "See that vec[#{symbol_idx}] is #{vec[symbol_idx]}" if FIND_DBG

        return false if node[vec[symbol_idx]].nil?
        node = children[vec[symbol_idx]]
      }
      return true
    end

    def find_superset_str(subset_str, &word_filter)
      find_superset WordUtils.word_to_vec(subset_str), &word_filter
    end

    # TODO: Optimization
    # Don't even bother searching if the word is too long, or if it has
    # more than the max number of any given character.
    #
    # TODO: Optimization
    # Constrain maximal count of each character to the number left in the
    # pool/words available.
    #
    # Returns: [result, cost]
    #   result: array of string words that are superset of subset_vec, or nil if
    #           none were found.
    #   cost: integer number of tree branches traversed
    def find_superset(subset_vec, &word_filter)
      _find_superset subset_vec, &word_filter
    end

    def _find_superset(subset_vec, level = 0, node = @root, &word_filter)
      puts "Finding #{subset_vec}" if level == 0 if FIND_SUBSET_DBG
      @accumulated_cost += 1
      my_cost = 1

      lv = level+1
      puts '| '*lv + "Finding lvl #{level}" if FIND_SUBSET_DBG

      if level == 26
        # node should be an array of strings (words that are supersets of
        # subset_vec)

        raise "Empty leaf node in LookupTree; it should never have been inserted in the first place" if node.nil? or node.empty?

        puts '| '*lv + "Supersets: #{node}" if FIND_SUBSET_DBG
        return node, my_cost
      end

      # idx is number in 0..25 representing next letter
      idx, children = node
      (subset_vec[idx] .. children.length-1).each {|possible_ct|
        puts '| '*lv+"#{('a'.ord+idx).chr}: #{possible_ct}" if FIND_SUBSET_DBG
        next_node = children[possible_ct]
        next if next_node.nil?
        res, sub_cost = _find_superset subset_vec, level+1, next_node, &word_filter
        my_cost += sub_cost

        res = word_filter.call(res) if res and word_filter
        if res and !res.empty?
          puts '| '*lv+"OK" if FIND_SUBSET_DBG
          return res, my_cost
        end
      }

      puts '| '*lv+"no" if FIND_SUBSET_DBG
      return nil, my_cost
    end

    def printout
      _printout
    end

    def _printout(node = @root, level = 0)
      lv = level+1
      if level == 26
        puts '| '*lv + node.to_s
        return
      end

      idx, children = node
      (0 .. children.length-1).each {|possible_ct|
        puts '| '*lv + ('a'.ord + idx).chr + " : #{possible_ct}\n"
        next if children[possible_ct].nil?
        _printout children[possible_ct], level+1
      }
    end

    def count_nodes
      _count_nodes
    end

    def _count_nodes(node = @root, level = 0)
      return 1 if level == 26

      sum = 1
      idx, children = node
      (0 .. children.length-1).each {|possible_ct|
        next if children[possible_ct].nil?
        sum += _count_nodes children[possible_ct], level+1
      }

      return sum
    end

    def describe
      return "smart_branch"
    end
  end
end
