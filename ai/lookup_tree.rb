def normalize_word(word)
  return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
end

# Possible improvement: decrease branching factor by changing order of letters
# to use least-varying letters first.
# Can also change the order per-branch by storing the next letter in each
# node.
#
# http://blog.notdot.net/2007/10/Damn-Cool-Algorithms-Part-3-Anagram-Trees
# http://blog.notdot.net/2007/10/Update-on-Anagram-Trees

class LookupTree
  attr_accessor :accumulated_cost

  def initialize
    clear_cost
  end

  def clear_cost
    @accumulated_cost = 0
  end

  FIND_SUBSET_DBG = false
  FIND_DBG = false

  def word_to_vec(word)
    word = normalize_word word
    vec = []
    a_ord = "a"[0].ord
    (0..25).each {|idx|
      letter = (a_ord + idx).chr
      vec[idx] = word.count(letter)
    }
    return vec
  end

  def initialize
    @root = []
  end

  def find(word, insert=false)
    vec = word_to_vec word

    puts word +" => "+ vec.to_s if FIND_DBG

    node = @root
    (0..25).each {|i|
      puts "See that vec[#{i}] is #{vec[i]}" if FIND_DBG
      if node[vec[i]].nil?
        if insert
          puts "  START NEW" if FIND_DBG
          node[vec[i]] = []
        else
          return false
        end
      end
      node = node[vec[i]]
    }
    node.push word
  end

  def find_superset_str(subset_str)
    cost = [0]
    res = find_superset(word_to_vec(subset_str), 0, @root, cost)

    puts "Cost: #{cost[0]}"
    @accumulated_cost += cost[0]
    return res
  end

  # TODO: Optimization
  # Don't even bother searching if the word is too long, or if it has
  # more than the max number of any given character.
  #
  # TODO: Optimization
  # Constrain maximal count of each character to the number left in the
  # pool/words available.
  def find_superset(subset_vec, i = 0, node = @root, cost = [0])
    puts "Finding #{subset_vec}" if i == 0 if FIND_SUBSET_DBG
    cost[0] += 1

    lv = i+1
    puts '| '*lv + "Finding lvl #{i}" if FIND_SUBSET_DBG

    if i == 26
      raise "Hmmm?" if node.empty?
      puts '| '*lv + "Supersets: #{node}" if FIND_SUBSET_DBG
      return node
    end

    return false if subset_vec[i] > node.length

    (subset_vec[i] .. node.length-1).each {|possible_ct|
      puts '| '*lv+"#{('a'.ord+i).chr}: #{possible_ct}" if FIND_SUBSET_DBG
      next_node = node[possible_ct]
      next if next_node.nil?
      res = find_superset(subset_vec, i+1, next_node, cost)
      if res
        puts '| '*lv+"OK" if FIND_SUBSET_DBG
        return res
      end
    }
    puts '| '*lv+"no" if FIND_SUBSET_DBG
    return false
  end

  def dump(node = @root, i = 0)
    lv = i+1
    if i == 26
      puts '| '*lv + node.to_s
      return
    end

    (0 .. node.length-1).each {|possible_ct|
      puts '| '*lv + ('a'.ord + i).chr + " : #{possible_ct}\n"
      next if node[possible_ct].nil?
      dump node[possible_ct], i+1
    }
  end
end
