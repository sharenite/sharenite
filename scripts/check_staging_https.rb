# frozen_string_literal: true

require "net/http"
require "openssl"

abort "This check is only for staging" unless Rails.env.staging?

host = URI(ENV.fetch("HOST")).host
http = Net::HTTP.new(host, 443, nil)
# Reach the origin directly while retaining the public hostname for SNI and
# certificate verification. Cloudflare Access gates unauthenticated public probes.
http.ipaddr = IPSocket.getaddress("kamal-proxy")
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_PEER
http.ca_file = Rails.root.join("config/certificates/cloudflare-origin-ca-rsa.pem").to_s
http.open_timeout = 10
http.read_timeout = 15

username = ENV["HTTP_BASIC_USER"].presence || Rails.application.credentials.dig(:http_basic, :user)
password = ENV["HTTP_BASIC_PASSWORD"].presence || Rails.application.credentials.dig(:http_basic, :password)

["/up", "/users/sign_in"].each do |path|
  request = Net::HTTP::Get.new(path)
  request.basic_auth(username, password) if username.present? && password.present?
  response = http.request(request)
  abort "Staging origin HTTPS #{path}: expected HTTP 200, got #{response.code}" unless response.code == "200"

  puts "Staging origin HTTPS #{path}: HTTP 200; certificate and hostname verified"
end
