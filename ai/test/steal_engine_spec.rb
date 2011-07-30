require 'set'
require 'word_utils'
require 'lookup_tree/smart_branch'
require 'lookup_tree/global_order'
require 'steal_engine'

shared_examples "StealEngine" do
  before(:all) do
    @lookup_tree = LookupTree::SmartBranch.new

    @dict = Set.new("When invoked with a block, yields all repeated combinations of length n of elements from ary and then returns ary itself. The implementation makes no guarantees about the order in which the repeated combinations are an yielded.".split.map! {|w| WordUtils.normalize_word_chars w})

    puts "#{@dict.to_a}"

    @lookup_tree.build @dict, build_opts
  end

  context "find_superset_str", :if => false do
    it "finds valid supersets exhaustive" do
    end
  end
  context "with a word-length filter" do
    it "finds valid supersets exhaustive" do
    end
  end
end

describe StealEngine do
  it_behaves_like "StealEngine" do
  end
end
