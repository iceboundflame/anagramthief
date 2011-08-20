
ENV['RAILS_ENV'] ||= 'development'
RAILS_ENV = ENV['RAILS_ENV']

$:.push File.dirname(__FILE__)+"/../lib"

require 'anathief_settings'
require 'app_server'

AppServer.new.run Anathief::AppServer::LISTEN_HOST, Anathief::AppServer::PORT
