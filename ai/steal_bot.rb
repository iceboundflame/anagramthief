require 'lookup_tree'
require 'steal_engine'

require 'eventmachine'
require 'em-synchrony'
#require 'web_socket_client'
require 'em-http-request'
require 'logger'
require 'json'

$log = Logger.new STDERR

HOST, PORT = 'localhost', '8123'
ID_TOKEN = '81:31:1311834508:7dd6efaa10b4779fb2625507428b01d81a08d4d8'

class StealBot
  def initialize(lookup_tree)
    @lookup_tree = lookup_tree
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

    @lookup_tree.clear_cost
    t = Time.now
    res, cost = StealEngine.search @lookup_tree, pool, stealable
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
        puts "IN << #{msg_}"

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




tree_file = ARGV[0]
unless tree_file
  puts "Usage: #{$0} lookup-tree.t2"
  exit
end

puts "Loading #{tree_file} tree"
of = File.new tree_file, 'r'
lookup_tree = Marshal.load of
of.close



StealBot.new(lookup_tree).run
