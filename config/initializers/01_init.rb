module Anathief
  settings_file = "#{Rails.root}/config/settings.yml"
  puts "Loading settings from #{settings_file}, env #{Rails.env}"
  SETTINGS = YAML.load_file(settings_file)["#{Rails.env}"]

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

  WORDNIK_KEY = SETTINGS['wordnik']['api_key']
end

# strangest interface...
Wordnik::Wordnik.new :api_key => Anathief::WORDNIK_KEY
Wordnik::Wordnik.default_timeout 2

unless MiniFB.method_defined?(:signed_request_params)
  puts "Monkey patching MiniFB"
  module MiniFB
    def self.signed_request_params(secret, req)
      s, p = req.split(".")
      p = base64_url_decode(p)
      h = JSON.parse(p)
      h.delete('algorithm') if h['algorithm'] == 'HMAC-SHA256'
      h
    end
  end
end
