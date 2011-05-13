class MyMultiset
  def initialize(args={})
    @hash = {}
    if args.include? :word
      from_letters args[:word]
    elsif args.include? :array
      from_array args[:array]
    elsif args.include? :hash
      from_hash args[:hash]
    end
  end

  # Sugar
  def self.from_letters(x); new.from_letters(x); end
  def self.from_array(x); new.from_array(x); end
  def self.from_hash(x); new.from_hash(x); end

  def from_letters(word)
    raise ArgumentError, 'need a String' unless word.kind_of?(String)
    from_array word.chars.to_a
  end
  def from_array(array)
    raise ArgumentError, 'need an Array' unless array.kind_of?(Array)
    @hash = {}
    array.each do |letter|
      @hash[letter] = @hash.fetch(letter, 0) + 1
    end
    self
  end
  def from_hash(hash)
    raise ArgumentError, 'need a hash' unless hash.kind_of?(Hash)
    @hash = hash.dup
    self
  end

  def to_a; to_array; end
  def to_array
    res = []
    @hash.each do |ltr, ct|
      res += [ltr] * ct
    end
    res
  end

  def to_hash
    @hash.dup
  end

  def to_s
    "#Multiset"+@hash.to_s
  end

  def to_letters
    return @hash.inject('') {|letters, (k, v)| letters + k * v}
  end

  def size
    @hash.values.inject(0) {|sum, ct| sum + ct}
  end

  def empty?
    @hash.empty? || size == 0
  end

  def ^(second)
    raise ArgumentError, 'need 2 of me' unless second.kind_of?(self.class)

    a = @hash.dup
    b = second.hash.dup
    (a.keys | b.keys).each do |k|
      acount = a.fetch(k, 0) - b.fetch(k, 0)
      if acount > 0
        a[k] = acount
      elsif acount < 0
        b[k] = -acount
      end
      a.delete(k) if acount <= 0
      b.delete(k) if acount >= 0
    end

    #return MyMultiset.from_hash(a), MyMultiset.from_hash(b)
    return self.class.from_hash(a), self.class.from_hash(b)
  end

  def *(second)
    raise ArgumentError, 'need 2 of me' unless second.kind_of?(self.class)

    b = second.hash
    intersect = @hash.inject({}) do |r, (k, my_v)|
      r[k] = [my_v, b.fetch(k, 0)].min
      r
    end

    return self.class.from_hash(intersect)
  end

  def -(second)
    raise ArgumentError, 'need 2 of me' unless second.kind_of?(self.class)

    b = second.hash
    intersect = @hash.inject({}) do |r, (k, my_v)|
      r[k] = [0, my_v - b.fetch(k, 0)].max
      r
    end

    return self.class.from_hash(intersect)
  end

  def each
    hash.each { |id, ct| yield id, ct }
  end

  def keys
    hash.keys
  end

  def [](key)
    hash[key]
  end

  # Weighted random selection
  def random_elem
    letters = @hash.keys
    running_ct = 0
    cdf = letters.map { |ltr| running_ct += @hash[ltr]; running_ct }
    return nil if running_ct == 0

    randValue = rand
    cdf.size.times do |idx|
      return letters[idx] if randValue <= cdf[idx].to_f/running_ct
    end
    return nil
  end

  def remove(elem, n=1)
    return remove_all elem if n < 0
    return unless @hash.include? elem
    remain = (@hash[elem] -= n)
    @hash.delete elem if remain <= 0
  end
  def remove_all(elem)
    @hash.delete elem
  end

  def to_data
    @hash
  end

  def self.from_data(x); new.from_data(x); end
  def from_data(data)
    @hash = data
    self
  end

  protected
  attr_accessor :hash
end




class Node
  attr_accessor :is_word, :children

  def initialize(is_word = false)
    @is_word = is_word
    @children = []
  end
end


def normalize_word(word)
  return word.downcase.gsub(/[^a-z]/, '').chars.to_a.sort.join('')
end

def make_word(tree, word)
  if tree.include? word
    tree[word].is_word = true
  else
    tree[word] = Node.new(true)
  end
end

@anagrams = Hash.new {|hash, key| hash[key] = []}

def update_tree(tree, word)
  @anagrams[normalize_word(word)].push word
  do_update_tree(tree, normalize_word(word))
end

$skip = 0

def do_update_tree(tree, word, cur='', lv=1, seen = {})
  dbg= false

  if seen.include? cur
    $skip += 1
    return
  end
  seen[cur] = true

  puts '  '*lv + "** Update tree: '#{word}' from node '#{cur}'" if dbg

  if word == cur
    puts '  '*lv + "Word found!" if dbg
    tree[word].is_word = true
    return
  end

  word_ms = MyMultiset.from_letters word
  cur_ms = MyMultiset.from_letters cur
  node = tree[cur]
  new_children = []
  found = false
  node.children.delete_if { |child|
    print '  '*lv + "Child: #{child} : " if dbg

    remove_child = false
    child_ms = MyMultiset.from_letters child
    isect = word_ms * child_ms
    isect_unique = isect - cur_ms
    if !isect_unique.empty?
      found = true

      not_in_child_ms, not_in_word_ms = word_ms ^ child_ms
      if not_in_word_ms.empty?
        puts "following" if dbg

        # This child node is (at least part of) the word we are looking for.
        # Follow it.
        do_update_tree(tree, word, child, lv+1, seen)
      else
        # Split child node
        common_parent = normalize_word(isect.to_letters)

        puts "splitting => #{common_parent} branch to #{child}, #{word}" if dbg

        remove_child = true
        new_children.push common_parent
        if !tree.include? common_parent
          branch = Node.new(false)
          branch.children = [child, word]
          tree[common_parent] = branch
        end

        make_word tree, word
      end
    else
      puts "irrelevant" if dbg
    end

    remove_child
  }
  node.children += new_children
  if !found
    make_word tree, word
    node.children.push word
  end
end

def dump_tree(tree, cur='', lv=1, seen = {})
  node = tree[cur]
  print '  '*lv + "'#{cur}'"
  print " => [ #{@anagrams[cur].join ', '} ]" if node.is_word
  print ' ...' if seen.include? cur
  puts

  return if seen.include? cur
  seen[cur] = true

  node.children.each {|chi|
    dump_tree(tree, chi, lv+1, seen)
  }
end

def tree_stat(tree)
  nlinks = tree.inject(0) {|s,(k,v)| s + v.children.size}
  size = tree.inject(0) { |s,(k,v)| s + v.children.inject(0) {|l, v| l + v.length} }

  print "    "
  print "Nodes: #{tree.size} ; "
  print "Links: #{nlinks} ; "
  print "Links Aggregate Size: #{size}"
  print "\n"
end

tree = {'' => Node.new}

if true
  words = ['dog', 'sit', 'goads', 'simplification', 'soa']
  #words = ['dog', 'goads', 'sit'] # FAILS THIS CASE! no 's' node

  #words = "When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split

  words.each {|x|
    puts "\nADDING: #{x}"
    update_tree(tree, x)
    puts "\nRESULT:"
    dump_tree(tree)
  }
end

begin
  file = ARGV[0]
  i = 0
  IO.foreach(file) { |line|
    i += 1
    #print '.' if i % 1000 == 0
    line.chomp!
    update_tree(tree, line.downcase)

    if i % 100 == 0
      puts "[n=#{i}; skip=#{$skip}] #{line}"
      $skip = 0
      tree_stat tree
    end
  }
rescue Interrupt
end

#dump_tree (tree)
tree_stat(tree)

#puts MyMultiset.from_letters("helloworldthere").to_letters
