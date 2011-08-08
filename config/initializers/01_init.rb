require 'anathief_settings'

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
