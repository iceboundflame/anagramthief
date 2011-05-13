def normalize_word(word)
  return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
end

class LookupTree
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
    dbg = false
    vec = word_to_vec word

    puts word +" => "+ vec.to_s if dbg

    node = @root
    (0..25).each {|i|
      puts "See that vec[#{i}] is #{vec[i]}" if dbg
      if node[vec[i]].nil?
        if insert
          puts "  START NEW" if dbg
          node[vec[i]] = []
        else
          return false
        end
      end
      node = node[vec[i]]
    }
    node.push word
  end

  def find_with_subset_str(str)
    cost = [0]
    res = find_with_subset(word_to_vec(str), 0, @root, cost)

    #puts "Cost: #{cost[0]}"
    return res
  end

  def find_with_subset(subset_vec, i = 0, node = @root, cost = [0])
    #puts "Finding #{subset_vec}" if i == 0
    cost[0] += 1

    lv = i+1
    #puts '| '*lv + "Finding lvl #{i}"

    if i == 26
      raise "Hmmm?" if node.empty?
      #puts '| '*lv + "Supersets: #{node}"
      return node
    end

    return false if subset_vec[i] > node.length

    (subset_vec[i] .. node.length-1).each {|possible_ct|
      #puts '| '*lv+"#{('a'.ord+i).chr}: #{possible_ct}"
      next_node = node[possible_ct]
      next if next_node.nil?
      res = find_with_subset(subset_vec, i+1, next_node, cost)
      if res
        #puts '| '*lv+"OK"
        return res
      end
    }
    #puts '| '*lv+"no"
    return false
  end

  def print(node = @root, i = 0)
    lv = i+1
    if i == 26
      puts '| '*lv + node.to_s
      return
    end

    (0 .. node.length-1).each {|possible_ct|
      puts '| '*lv + ('a'.ord + i).chr + " : #{possible_ct}\n"
      next if node[possible_ct].nil?
      dump(node[possible_ct], i+1)
    }
  end
end
