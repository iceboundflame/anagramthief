require 'test/unit'

require 'word_utils'

class TestLookupTree < Test::Unit::TestCase
  require 'lookup_tree/smart_branch'

  def setup
    @dict = "When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split.map! {|w| WordUtils.normalize_word_chars w}

    @lookup_tree = LookupTree::SmartBranch.new
    @lookup_tree.build(@dict)
  end

  def assert_is_superset(subset, superset)
    assert_equal 26, subset.size
    assert_equal 26, superset.size

    (0..25).each {|i|
      assert subset[i] <= superset[i]
    }
  end

  def assert_valid_supersets(from_chars, supersets)
    puts "#{from_chars} => #{supersets}"
    from_vec = WordUtils.word_to_vec from_chars
    supersets.each {|superset|
      assert @dict.include? superset
      assert_is_superset from_vec, WordUtils.word_to_vec(superset)
    }
  end

  def test_simple
    # words with matches
    %w(w h yie).each {|w|
      res, cost = @lookup_tree.find_superset_str(w)
      assert_valid_supersets w, res
      assert cost > 0
    }
    %w(wz hs yiez).each {|w|
      res, cost = @lookup_tree.find_superset_str(w)
      assert_nil res
      assert cost > 0
    }
  end
end
