# frozen_string_literal: true

# Job that performs an IGDB authentication call
class IgdbAuthenticate
  def call
    refresh_authentication_token
  end

  # rubocop:disable Metrics:AbcSize
  # rubocop:disable Style/GlobalVars
  def refresh_authentication_token
    url = URI("https://id.twitch.tv/oauth2/token?client_id=#{ENV.fetch('IGDB_CLIENT_ID', nil)}&client_secret=#{ENV.fetch('IGDB_CLIENT_SECRET', nil)}&grant_type=client_credentials")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)

    response = http.request(request)
    response_body = JSON.parse(response.read_body)

    $redis.set("idgb_token", { access_token: response_body["access_token"], expires_at: (Time.current + response_body["expires_in"].to_i.seconds).to_i }.to_json)
  end
  # rubocop:enable all
end
