require 'steal_engine'

if ARGV.length < 2
  puts "Usage: #{$0} [tree-type] [tree-file]"
  exit 1
end

type, infile = ARGV

unless require "lookup_tree/#{type}"
  puts "Invalid tree type #{type}: No such file lookup_tree/#{type}.rb"
  exit 1
end

puts "Loading #{infile}"
lookup_tree = nil
File.open(infile, 'r') {|fh| lookup_tree = Marshal.load fh}


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
