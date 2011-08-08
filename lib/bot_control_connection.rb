require 'singleton'
require 'json'

class BotControlConnection
  include Singleton

  def check_conn
    return if @sock and !@sock.closed?

    @sock = Socket.tcp(Anathief::BotControl::CONNECT_HOST,
                       Anathief::BotControl::PORT)
  end

  # N.B. not thread-safe!
  def request(type, data={})
    check_conn

    @sock.send({:_t => type}.merge(data).to_json + "\r\n", 0)
    return JSON.parse(@sock.readline)
  end
end
