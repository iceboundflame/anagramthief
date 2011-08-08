class AppServer::Client
  attr_accessor :ws, :game_id, :user_id

  def conn_id
    ws.object_id
  end

  def initialize(ws)
    @game_id = @user_id = nil
    @ws = ws
  end

  def user_id=(val)
    @user_id = val.to_s
  end

  def identified?
    return !game_id.nil?
  end

  def respond(serial, ok, data={})
    ws.send({
        :_t => 'response',
        :_s => serial,
        :ok => ok
      }.merge(data).to_json)
  end

  def send_message(type, data={})
    ws.send({:_t => type}.merge(data).to_json)
  end
end
