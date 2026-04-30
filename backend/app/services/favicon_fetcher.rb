# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'openssl'

class FaviconFetcher
  TIMEOUT = 5

  def self.call(site_url)
    new(site_url).call
  end

  def initialize(site_url)
    @site_url = site_url.to_s.chomp('/')
  end

  def call
    favicon_url = "#{@site_url}/favicon.ico"
    uri = URI.parse(favicon_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.head(uri.request_uri)
    response.is_a?(Net::HTTPSuccess) ? favicon_url : nil
  rescue StandardError
    nil
  end
end
