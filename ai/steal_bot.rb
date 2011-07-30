require 'lookup_tree/global_order'
require 'lookup_tree/smart_branch'
require 'steal_engine'

require 'eventmachine'
require 'em-synchrony'
require 'em-http-request'
require 'logger'
require 'json'

$log = Logger.new STDERR

HOST, PORT = 'localhost', '8123'
ID_TOKEN = '82:32:1312013178:8903bb28b542417147921a7c9d39ed55430edad6'

MIN_LEN = 3

class StealBot
  def initialize(lookup_tree, ranks, max_rank, max_steal_len)
    @lookup_tree = lookup_tree
    @ranks = ranks
    @max_rank = max_rank
    @max_steal_len = max_steal_len

    @serial = 1
  end

  def ssend(type, data={})
    serial = @serial
    @serial += 1
    msg = {:_t => type, :_s => serial}.merge(data).to_json
    puts "OUT>> #{msg}"
    @http.send msg
  end

  def got_update(msg)
    stealable = []
    msg['players_order'].each do |p_id|
      stealable += msg['players'][p_id]['words']
    end

    pool = msg['pool']

    puts "#{stealable} and #{pool}"

    word_filter = lambda {|words| words.select {|w| w.length >= MIN_LEN and (@max_rank == 0 or (@ranks.include? w and @ranks[w] <= @max_rank))}}

    @lookup_tree.clear_cost
    t = Time.now
    res, cost = StealEngine.search @lookup_tree, pool, stealable, @max_steal_len, &word_filter
    t = Time.now - t

    puts "Stealengine: #{res}"
    puts "#{t*1000}ms"
    puts "#{@lookup_tree.accumulated_cost} total cost (== #{cost})"

    if res
      word = res[0]
      puts "Claiming #{word}"

      ssend 'claim', {:word => word}

    else
      puts "Flipping char..."

      #sleep 1

      ssend 'flip'
    end
  end

  def run
    $log.info "StealBot starting"
    EventMachine.synchrony do
      puts '='*80, "Connecting to websockets server at ws://#{HOST}:#{PORT}", '='*80

      @http = EventMachine::HttpRequest.new("ws://#{HOST}:#{PORT}/websocket").get :timeout => 0

      @http.errback do
        puts "oops, error"
      end

      @http.callback do
        puts "#{Time.now.strftime('%H:%M:%S')} : Connected to server"

        ssend 'identify', {:id_token => ID_TOKEN}
      end

      @http.stream do |msg_|
        #puts "IN << #{msg_}"

        begin
          msg = JSON.parse(msg_)

          if msg['_t'] == 'update'
            got_update msg
          end

        rescue StandardError => e
          $log.error ": (StandardError) #{e.inspect}\n#{e.backtrace.join "\n"}"

        end
      end

      @http.disconnect do
        puts "Oops, dropped connection?"
      end
    end
  end
end


if ARGV.length < 2
  puts "Usage: #{$0} [lookup-tree] [freq-list] [max-rank=30000] [max-steal-len=5]"
  exit 1
end

tree_file, freq_file, max_rank, max_steal_len = ARGV
max_rank ||= 30000
max_rank = max_rank.to_i

max_steal_len ||= 30000
max_steal_len = max_steal_len.to_i

lookup_tree = ranks = nil

puts "Loading #{tree_file} tree"
File.open(tree_file, 'r') {|fh| lookup_tree = Marshal.load fh}

puts "Loading #{freq_file} freqs"
File.open(freq_file, 'r') {|fh| ranks = Marshal.load fh}

StealBot.new(lookup_tree, ranks, max_rank, max_steal_len).run
