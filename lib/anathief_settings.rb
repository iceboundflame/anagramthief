module Anathief
  require 'yaml'

  settings_file = File.expand_path(File.dirname(__FILE__) + "/../config/settings.yml")
  puts "Loading settings from #{settings_file}, env #{RAILS_ENV}"
  SETTINGS = YAML.load_file(settings_file)["#{RAILS_ENV}"]

  module Facebook
    APP_ID = SETTINGS['facebook']['app_id']
    SECRET = SETTINGS['facebook']['app_secret']
    CANVAS_URL = SETTINGS['facebook']['canvas_url']
  end

  module AppServer
    LISTEN_HOST = SETTINGS['app_server']['listen_host']
    CONNECT_HOST = SETTINGS['app_server']['connect_host']
    PORT = SETTINGS['app_server']['port']
    SIOWS_URL = SETTINGS['app_server']['siows_url']
  end

  module BotControl
    LISTEN_HOST = SETTINGS['bot_control']['listen_host']
    CONNECT_HOST = SETTINGS['bot_control']['connect_host']
    PORT = SETTINGS['bot_control']['port']
  end

  module Internal
    ALLOWED_HOSTS = SETTINGS['internal']['allowed_hosts']
    ENDPOINT = SETTINGS['internal']['endpoint']
  end

  WORDNIK_KEY = SETTINGS['wordnik']['api_key']

  TOKEN_SECRET = SETTINGS['token_secret']
end

require 'wordnik'
puts "Initializing Wordnik..."
Wordnik.configure do |config|
  config.api_key = Anathief::WORDNIK_KEY
  #config.default_timeout 2
end
