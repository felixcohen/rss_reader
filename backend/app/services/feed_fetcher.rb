# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'feedjira'
require 'loofah'

class FeedFetcher
  TIMEOUT = 15

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    result = fetch_body
    return result if result.key?(:error)

    parsed = parse_feed(result[:body])
    return { error: 'Could not parse feed' } if parsed.nil?

    feed = upsert_feed(parsed)
    upsert_items(feed, parsed.entries)
    { feed: feed.refresh }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def fetch_body
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.get(uri.request_uri, 'User-Agent' => 'RSSReader/1.0')
    return { error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

    { body: response.body }
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    { error: "Timeout: #{e.message}" }
  rescue SocketError, Errno::ECONNREFUSED => e
    { error: "Connection error: #{e.message}" }
  end

  def parse_feed(body)
    Feedjira.parse(body)
  rescue StandardError
    nil
  end

  def upsert_feed(parsed)
    existing = Feed[url: @url]
    if existing
      existing.update(last_fetched_at: Time.now)
      return existing
    end

    Feed.create(
      url: @url,
      title: parsed.title&.strip,
      site_url: parsed.url,
      description: parsed.description&.strip,
      last_fetched_at: Time.now
    )
  end

  def upsert_items(feed, entries)
    entries.each do |entry|
      guid = entry.entry_id || entry.url
      next if guid.nil?
      next if FeedItem[feed_id: feed.id, guid: guid]

      content = sanitise(entry.content || entry.summary)
      FeedItem.create(
        feed_id: feed.id,
        guid: guid,
        title: entry.title&.strip,
        url: entry.url,
        content_html: content,
        summary: Loofah.fragment(entry.summary.to_s).to_text.strip[0, 500],
        author: entry.author&.strip,
        published_at: entry.published || Time.now,
        fetched_at: Time.now,
        is_read: false,
        is_starred: false
      )
    rescue StandardError
      next
    end
  end

  def sanitise(html)
    return '' if html.nil? || html.empty?

    Loofah.fragment(html).scrub!(:strip).to_s
  end
end
