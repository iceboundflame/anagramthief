require 'eventmachine'
require 'em-synchrony'
require 'em-websocket'

require 'log4r-color'
require 'json'

class StealBotControlServer
  attr_accessor :bots

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

  def add_bot(user_id, play_token, settings)
    if @bots.include? user_id
      @bots[user_id].stop
    end

    bot = @bots[user_id] = StealBot.new(user_id, @lookup_tree, @word_ranks, play_token, settings)
    bot.run
  end

  def list_bots
    list = {}
    @bots.each do |user_id, bot|
      list[user_id] = bot.settings
    end

    return list
  end

  def get_bot(user_id)
    @bots[user_id]
  end

  def run(host, port)
    EventMachine.synchrony do
      EventMachine::start_server host, port, CtrlConnection, self
      @@log.info "Started StealBotMaster on #{host}:#{port}"
    end
  end
end

class CtrlConnection < EventMachine::Connection
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
  @@log = Logger.new('CtrlConnection')
  @@log.add('color')
  include EM::Protocols::LineText2

  def initialize(ctrl)
    @ctrl = ctrl

    @@log.info loghead+"connected"
  end

  def receive_line(msg_)
    @@log.debug loghead+"message: #{msg_}"

    begin
      msg = JSON.parse(msg_)
      if ['add_bot', 'list_bots', 'set_bot', 'remove_bot', 'remove_all_bots'].include? msg['_t']
        # Call handle_XYZ
        send "handle_#{msg['_t']}", msg
      else
        raise ApiError, "Unknown message type '#{msg['_t']}'"
      end
    rescue StandardError => e
      @@log.error loghead+"(StandardError) #{e.inspect}\n#{e.backtrace.join "\n"}"
      respond false, {:message => "Internal error"}
    end
  end

  def unbind
    @@log.info loghead+"disconnected"
  end

  #self.onerror do |error|
    #@@log.error loghead+"SOCKET ERROR: #{error}"
  #end

  def respond(ok, data={})
    ssend({
        :_t => 'response',
        :ok => ok
      }.merge(data).to_json)
  end
  def ssend(data)
    send_data "#{data}\r\n"
  end

  def loghead
    "#{object_id}: "
  end

  def handle_add_bot(msg)
    user_id = msg['user_id'].to_s
    play_token = msg['play_token']
    settings = msg['settings']

    @ctrl.add_bot user_id, play_token, settings

    respond true
  end

  def handle_list_bots(msg)
    respond true, {:bots => @ctrl.list_bots}
  end

  def handle_set_bot(msg)
    user_id = msg['user_id'].to_s
    settings = msg['settings']

    bot = @ctrl.get_bot user_id
    respond false, {:error => "No bot #{user_id}"} unless bot
    bot.settings = settings

    respond true
  end

  def handle_remove_bot(msg)
    user_id = msg['user_id'].to_s

    bot = @ctrl.bots.delete user_id
    respond false, {:error => "No bot #{user_id}"} unless bot
    bot.stop

    respond true
  end

  def handle_remove_all_bots(msg)
    # HACK
    @ctrl.bots.each do |uid, bot|
      bot.stop
    end
    @ctrl.bots.clear
    respond true
  end
end
