# Superseded by global_order with option :alpha_order => true

#require 'word_utils'

## Possible improvement: decrease branching factor by changing order of letters
## to use least-varying letters first.
## Can also change the order per-branch by storing the next letter in each
## node.
##
## http://blog.notdot.net/2007/10/Damn-Cool-Algorithms-Part-3-Anagram-Trees
## http://blog.notdot.net/2007/10/Update-on-Anagram-Trees

#module LookupTree
  #class Basic
    #attr_accessor :accumulated_cost

    #def initialize(words)
      #clear_cost
      #@root = []
    #end

    #def clear_cost
      #@accumulated_cost = 0
    #end

    #FIND_SUBSET_DBG = false
    #FIND_DBG = false

    #def find(word, insert=false)
      #vec = WordUtils.word_to_vec word

      #puts word +" => "+ vec.to_s if FIND_DBG

      #node = @root
      #(0..25).each {|i|
        #puts "See that vec[#{i}] is #{vec[i]}" if FIND_DBG
        #if node[vec[i]].nil?
          #if insert
            #puts "  START NEW" if FIND_DBG
            #node[vec[i]] = []
          #else
            #return false
          #end
        #end
        #node = node[vec[i]]
      #}
      #node.push word
    #end

    #def find_superset_str(subset_str)
      #find_superset WordUtils.word_to_vec(subset_str)
    #end

    ## TODO: Optimization
    ## Don't even bother searching if the word is too long, or if it has
    ## more than the max number of any given character.
    ##
    ## TODO: Optimization
    ## Constrain maximal count of each character to the number left in the
    ## pool/words available.
    ##
    ## Returns: [result, cost]
    ##   result: array of string words that are superset of subset_vec, or nil if
    ##           none were found.
    ##   cost: integer number of tree branches traversed
    #def find_superset(subset_vec)
      #_find_superset subset_vec
    #end

    #def _find_superset(subset_vec, i = 0, node = @root)
      #puts "Finding #{subset_vec}" if i == 0 if FIND_SUBSET_DBG
      #@accumulated_cost += 1
      #my_cost = 1

      #lv = i+1
      #puts '| '*lv + "Finding lvl #{i}" if FIND_SUBSET_DBG

      #if i == 26
        ## node should be an array of strings (words that are supersets of
        ## subset_vec)

        #raise "Empty leaf node in LookupTree; it should never have been inserted in the first place" if node.nil? or node.empty?

        #puts '| '*lv + "Supersets: #{node}" if FIND_SUBSET_DBG
        #return node, my_cost
      #end

      ## TODO remove this
      ##return nil, my_cost if subset_vec[i] > node.length

      #(subset_vec[i] .. node.length-1).each {|possible_ct|
        #puts '| '*lv+"#{('a'.ord+i).chr}: #{possible_ct}" if FIND_SUBSET_DBG
        #next_node = node[possible_ct]
        #next if next_node.nil?
        #res, sub_cost = _find_superset subset_vec, i+1, next_node
        #my_cost += sub_cost

        #if res and _has_long_enough(res)
          #puts '| '*lv+"OK" if FIND_SUBSET_DBG
          #return res, my_cost
        #end
      #}

      #puts '| '*lv+"no" if FIND_SUBSET_DBG
      #return nil, my_cost
    #end

    #def _has_long_enough(words)
      #words[0].length >= 3
    #end

    #def printout
      #_printout
    #end

    #def _printout(node = @root, i = 0)
      #lv = i+1
      #if i == 26
        #puts '| '*lv + node.to_s
        #return
      #end

      #(0 .. node.length-1).each {|possible_ct|
        #puts '| '*lv + ('a'.ord + i).chr + " : #{possible_ct}\n"
        #next if node[possible_ct].nil?
        #_printout node[possible_ct], i+1
      #}
    #end
  #end
#end
