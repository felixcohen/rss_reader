# frozen_string_literal: true

require_relative 'feed_fetcher'
require_relative 'favicon_fetcher'

class FeedPoller
  def self.poll_one(feed)
    new(feed).poll
  end

  def self.poll_all
    due_feeds.each { |feed| new(feed).poll }
  end

  def self.due_feeds
    Feed.where(
      Sequel.lit(
        'last_fetched_at IS NULL OR ' \
        'last_fetched_at <= datetime("now", "-" || fetch_interval_minutes || " minutes")'
      )
    ).all
  end

  def initialize(feed)
    @feed = feed
  end

  def poll
    result = FeedFetcher.call(@feed.url)

    if result[:error]
      @feed.update(last_error: result[:error])
    else
      updates = { last_fetched_at: Time.now, last_error: nil }
      if @feed.favicon_url.nil? && @feed.site_url
        updates[:favicon_url] = FaviconFetcher.call(@feed.site_url)
      end
      @feed.update(updates)
    end
  rescue StandardError => e
    @feed.update(last_error: e.message)
  end
end
