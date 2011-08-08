module SignedData
  def self.encode(data={})
    json = data.to_json
    return "#{sign(json)}:#{json}"
  end

  def self.decode(data)
    sig, json = data.split(':', 2)
    return nil unless sig == sign(json)
    return JSON.parse json
  end

  protected
  def self.sign(text)
    Digest::SHA1.hexdigest("#{Anathief::TOKEN_SECRET}:#{text}")
  end
end
