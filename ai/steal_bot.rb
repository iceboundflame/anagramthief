
ENV['RAILS_ENV'] ||= 'development'
RAILS_ENV = ENV['RAILS_ENV']

$:.push File.dirname(__FILE__)+"/lib"
$:.push File.dirname(__FILE__)+"/../lib"

require 'anathief_settings'
require 'log4r-color'

require 'steal_bot_control_server'
require 'steal_bot'
#require 'lookup_tree/global_order'
require 'lookup_tree/smart_branch'

include Log4r
#Logger = Log4r::Logger

ColorOutputter.new 'color', {:colors =>
  {
    :debug  => :dark_gray,
    :info   => :light_blue,
    :warn   => :yellow,
    :error  => :pink,
    :fatal  => {:color => :red, :background => :white}
  }
}

#$log = Logger.new('steal_bot', INFO)
$log = Logger.new('steal_bot', DEBUG)
$log.add('color')

if ARGV.length < 2
  puts "Usage: #{$0} [lookup-tree] [freq-list]"
  exit 1
end

tree_file, freq_file = ARGV

lookup_tree = word_ranks = nil

$log.info "Loading #{tree_file} tree"
File.open(tree_file, 'r') {|fh| lookup_tree = Marshal.load fh}

$log.info "Loading #{freq_file} freqs"
File.open(freq_file, 'r') {|fh| word_ranks = Marshal.load fh}

StealBotControlServer.new(lookup_tree, word_ranks).run(
  Anathief::BotControl::LISTEN_HOST,
  Anathief::BotControl::PORT,
)
