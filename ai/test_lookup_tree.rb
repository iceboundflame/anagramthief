load 'lookup_tree.rb'

puts "Loading #{ARGV[0]} tree"
of = File.new ARGV[0], 'r'
ltr = Marshal.load of
of.close

while true
  print "\n SUBSET> "
  subset = $stdin.gets
  if ltr.find_with_subset_str(subset)
    puts "FOUND"
  else
    puts "no"
  end
end
