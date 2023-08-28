# frozen_string_literal: true

# Job that performs call to get game from IGDB by id
class IgdbGetGame
  def initialize(igdb_id)
    @igdb_id = igdb_id
  end

  def call
    check_authentication_token
    call_igdb
  end

  # rubocop:disable Style/GlobalVars
  def check_authentication_token
    @token = JSON.parse($redis.get('idgb_token'))
    IgdbAuthenticate.new.call if @token.nil? || Time.at(@token['expires_at']).utc < Time.current
    @token = JSON.parse($redis.get('idgb_token'))
  end
  # rubocop:enable all

  # rubocop:disable Metrics:AbcSize
  def call_igdb
    url = URI("https://api.igdb.com/v4/games")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Post.new(url)
    request["Client-ID"] = ENV.fetch('IGDB_CLIENT_ID', nil)
    request["Content-Type"] = 'text/plain'
    request["Authorization"] = "Bearer #{@token['access_token']}"
    request.body = "fields name; where id = #{@igdb_id};"
    
    response = http.request(request)

    idgb_game = JSON.parse(response.body.force_encoding("UTF-8"))&.first

    IgdbCache.find_or_create_by(igdb_id: idgb_game['id'], name: idgb_game['name'])
  end
  # rubocop:enable all
end