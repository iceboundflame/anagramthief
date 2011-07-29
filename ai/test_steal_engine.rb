require 'lookup_tree'
require 'steal_engine'

tree_file = ARGV[0]
unless tree_file
  puts "Usage: #{$0} lookup-tree.t2"
  exit
end

puts "Loading #{tree_file} tree"
of = File.new tree_file, 'r'
lookup_tree = Marshal.load of
of.close

#pool_avail = 's'.chars.to_a
##words_avail = ['tile', 'tango', 'turn', 'faeries'] #, 'rifer', 'spile', 'wile']#, 'cameo']
#words_avail = ['tile', 'turn']

pool = 'zxs'.chars.to_a
stealable = ['tiler', 'tango', 'faeries', 'rifer', 'spile', 'wile', 'cameo']

#pool = 'ucohxarilie'.chars.to_a
#stealable = ['five', 'bookie', 'grip', 'gaits', 'clout']

lookup_tree.clear_cost
t = Time.now
res, cost = StealEngine.search lookup_tree, pool, stealable
t = Time.now - t

puts "Stealengine: #{res}"
puts "#{t*1000}ms"
puts "#{lookup_tree.accumulated_cost} total cost (== #{cost})"
