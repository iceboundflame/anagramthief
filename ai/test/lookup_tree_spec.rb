require 'set'
require 'word_utils'
require 'lookup_tree/smart_branch'
require 'lookup_tree/global_order'

shared_examples "LookupTree" do
  before(:all) do
    @lookup_tree = described_class.new

    @dict = Set.new("When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split.map! {|w| WordUtils.normalize_word_chars w})

    puts "#{@dict.to_a}"

    lookup_tree.build @dict, build_opts
  end

  context "find" do

  end

  context "find_superset_str", :if => false do
    it "finds valid supersets exhaustive" do
      tried = Set.new
      @dict.each {|w|
        (0..w.length).each {|len|
          w.chars.to_a.combination(len) {|subset|
            subset_str = subset.join ''
            norm = WordUtils.normalize_word(subset_str)
            next if tried.include? norm
            tried.add norm

            res, cost = lookup_tree.find_superset_str(subset_str)
            #puts "#{subset_str} => #{res} (#{cost})"
            print "."

            assert_valid_supersets subset_str, res
            cost.should be > 0
          }
        }
      }
    end
    it "does not find supersets where none exist" do
      %w(wz hs yiez zzzz).each {|w|
        res, cost = lookup_tree.find_superset_str(w)
        res.should be_nil
        cost.should be > 0
      }
    end
  end
  context "with a word-length filter" do
    it "finds valid supersets exhaustive" do
      MIN_LEN = 3
      filter = lambda { |words| words.select {|w| w.length >= MIN_LEN} }

      tried = Set.new
      @dict.each {|w|
        (0..w.length).each {|len|
          w.chars.to_a.combination(len) {|subset|
            subset_str = subset.join ''
            norm = WordUtils.normalize_word(subset_str)
            next if tried.include? norm
            tried.add norm

            res, cost = lookup_tree.find_superset_str(subset_str, &filter)
            #puts "#{norm} => #{res} (#{cost})"
            print "."

            if res.nil? or res.empty?
              w.length.should be < MIN_LEN
            else
              filter.call(res).should =~ res
              assert_valid_supersets subset_str, res
            end
            cost.should be > 0
          }
        }
      }
    end
  end
end

def assert_is_superset(subset, superset)
  subset.size.should be 26
  superset.size.should be 26

  (0..25).each {|i|
    subset[i].should be <= superset[i]
  }
end

def assert_valid_supersets(from_chars, supersets)
  from_vec = WordUtils.word_to_vec from_chars
  supersets.each {|superset|
    @dict.should include(superset)
    assert_is_superset from_vec, WordUtils.word_to_vec(superset)
  }
end

describe LookupTree::GlobalOrder do
  it_behaves_like "LookupTree" do
    let(:lookup_tree) { subject }
    let(:build_opts) { {:alpha_order => true} }
  end
end
describe LookupTree::SmartBranch do
  it_behaves_like "LookupTree" do
    let(:lookup_tree) { subject }
    let(:build_opts) { {} }
  end
end
