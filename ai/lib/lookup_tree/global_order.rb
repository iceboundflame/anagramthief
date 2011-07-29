require 'word_utils'

# Possible improvement:
# Can also change the order per-branch by storing the next letter in each
# node.
#
# http://blog.notdot.net/2007/10/Damn-Cool-Algorithms-Part-3-Anagram-Trees
# http://blog.notdot.net/2007/10/Update-on-Anagram-Trees

module LookupTree
  class GlobalOrder
    attr_accessor :accumulated_cost

    def initialize
      clear_cost
      @root = []
      @words = []
    end

    def clear_cost
      @accumulated_cost = 0
    end

    FIND_SUBSET_DBG = false
    FIND_DBG = false

    def build(words, opts={})
      @words = words

      if opts[:alpha_order]
        @symbol_order = (0..25).to_a
      else
        puts "Computing best global symbol order..." if opts[:progress]
        _compute_symbol_order words
      end

      puts "Building tree..." if opts[:progress]
      i = 0
      words.each { |w|
        i += 1
        find w, true

        puts "[n=#{i}] #{w}" if i % 10000 == 0 if opts[:progress]
      }
    end
    def _compute_symbol_order(words)
      @symbol_counts = [0]*26
      words.each { |w|
        w_vec = WordUtils.word_to_vec(w)
        w_vec.each_index { |i|
          @symbol_counts[i] = [@symbol_counts[i], w_vec[i]].max
        }
      }

      # Least common symbols first
      @symbol_order = (0..25).sort {|x,y|
        @symbol_counts[x] <=> @symbol_counts[y]
      }
    end

    def find(word, insert=false)
      vec = WordUtils.word_to_vec word

      puts word +" => "+ vec.to_s if FIND_DBG

      node = @root
      @symbol_order.each {|idx|
        puts "See that vec[#{idx}] is #{vec[idx]}" if FIND_DBG
        if node[vec[idx]].nil?
          if insert
            puts "  START NEW" if FIND_DBG
            node[vec[idx]] = []
          else
            return false
          end
        end
        node = node[vec[idx]]
      }
      node.push word
    end

    def find_superset_str(subset_str)
      find_superset WordUtils.word_to_vec(subset_str)
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
    def find_superset(subset_vec)
      _find_superset subset_vec
    end

    def _find_superset(subset_vec, level = 0, node = @root)
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

      # TODO remove this
      #return nil, my_cost if subset_vec[level] > node.length

      # number in 0..25 representing next letter
      idx = subset_vec[level]
      (subset_vec[idx] .. node.length-1).each {|possible_ct|
        puts '| '*lv+"#{('a'.ord+idx).chr}: #{possible_ct}" if FIND_SUBSET_DBG
        next_node = node[possible_ct]
        next if next_node.nil?
        res, sub_cost = _find_superset subset_vec, level+1, next_node
        my_cost += sub_cost

        if res and _has_long_enough(res)
          puts '| '*lv+"OK" if FIND_SUBSET_DBG
          return res, my_cost
        end
      }

      puts '| '*lv+"no" if FIND_SUBSET_DBG
      return nil, my_cost
    end

    def _has_long_enough(words)
      words[0].length >= 3
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

      (0 .. node.length-1).each {|possible_ct|
        puts '| '*lv + ('a'.ord + @symbol_order[level]).chr + " : #{possible_ct}\n"
        next if node[possible_ct].nil?
        _printout node[possible_ct], level+1
      }
    end

    def get_letter_order
      @symbol_order.map {|idx| ('a'.ord + idx).chr}
    end

    def count_nodes
      _count_nodes
    end

    def _count_nodes(node = @root, level = 0)
      return 1 if level == 26

      sum = 1
      (0 .. node.length-1).each {|possible_ct|
        next if node[possible_ct].nil?
        sum += _count_nodes node[possible_ct], level+1
      }

      return sum
    end

    def describe
      return "globalorder_#{get_letter_order.join}"
    end
  end
end
