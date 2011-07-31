require 'eventmachine'
require 'em-synchrony'
require 'em-websocket'

require 'log4r-color'
require 'json'

class StealBotControlServer
  include Log4r
ColorOutputter.new 'color', {:colors =>
  {
    :debug  => :dark_gray,
    :info   => :light_blue,
    :warn   => :yellow,
    :error  => :pink,
    :fatal  => {:color => :red, :background => :white}
  }
}
  @@log = Logger.new('StealBotControlServer')
  @@log.add('color')

  def initialize(lookup_tree, word_ranks)
    @lookup_tree = lookup_tree
    @word_ranks = word_ranks

    @bots = {} # user_id => StealBot
  end

  def respond(ws, ok, data={})
    ws.send({
        :_t => 'response',
        :ok => ok
      }.merge(data).to_json)
  end

  def loghead(ws)
    "#{ws.object_id}: "
  end

  def run
    EventMachine.synchrony do
      EventMachine::WebSocket.start(:host => CTRL_HOST, :port => CTRL_PORT) do |ws|
        ws.onopen do
          @@log.info loghead(ws)+"connected"
        end

        ws.onmessage do |msg_|
          @@log.debug loghead(ws)+"message: #{msg_}"

          begin
            msg = JSON.parse(msg_)
            if ['add_bot', 'list_bots', 'set_bot', 'remove_bot'].include? msg['_t']
              # Call handle_XYZ
              send "handle_#{msg['_t']}", ws, msg
            else
              raise ApiError, "Unknown message type '#{msg['_t']}'"
            end
          rescue StandardError => e
            @@log.error loghead(ws)+"(StandardError) #{e.inspect}\n#{e.backtrace.join "\n"}"
            respond ws, false, {:message => "Internal error"}
          end
        end

        ws.onclose do
          @@log.info loghead(ws)+"disconnected"
        end

        ws.onerror do |error|
          @@log.error loghead(ws)+"SOCKET ERROR: #{error}"
        end
      end

      @@log.info "Started StealBotMaster"
    end
  end

  def handle_add_bot(ws, msg)
    user_id = msg['user_id']
    play_token = msg['play_token']
    settings = msg['settings']

    if @bots.include? user_id
      @bots[user_id].stop
    end

    bot = @bots[user_id] = StealBot.new(user_id, @lookup_tree, @word_ranks, play_token, settings)
    bot.run

    respond ws, true
  end

  def handle_list_bots(ws, msg)
    list = {}
    @bots.each do |user_id, bot|
      list[user_id] = bot.settings
    end
    respond ws, true, {:bots => list}
  end

  def handle_set_bot(ws, msg)
    user_id = msg['user_id']
    settings = msg['settings']

    bot = @bots[user_id]
    respond ws, false, "No bot #{user_id}" unless bot
    bot.settings = settings

    respond ws, true
  end

  def handle_remove_bot(ws, msg)
    user_id = msg['user_id']

    bot = @bots.delete user_id
    respond ws, false, "No bot #{user_id}" unless bot
    bot.stop

    respond ws, true
  end
end
