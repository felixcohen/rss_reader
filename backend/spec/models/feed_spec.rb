# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Feed do
  describe 'validations' do
    it 'is valid with a url' do
      expect(Feed.new(url: 'https://example.com/feed').valid?).to be true
    end

    it 'is invalid without a url' do
      feed = Feed.new(url: nil)
      expect(feed.valid?).to be false
      expect(feed.errors[:url]).not_to be_empty
    end

    it 'enforces unique url' do
      create(:feed, url: 'https://example.com/feed')
      expect(Feed.new(url: 'https://example.com/feed').valid?).to be false
    end
  end

  describe '#unread_count' do
    it 'counts only unread items' do
      feed = create(:feed)
      create(:feed_item, feed: feed, is_read: false)
      create(:feed_item, feed: feed, is_read: false)
      create(:feed_item, feed: feed, is_read: true)
      expect(feed.unread_count).to eq(2)
    end

    it 'returns 0 when all items are read' do
      feed = create(:feed)
      create(:feed_item, feed: feed, is_read: true)
      expect(feed.unread_count).to eq(0)
    end

    it 'returns 0 with no items' do
      expect(create(:feed).unread_count).to eq(0)
    end

    it 'does not count items from other feeds' do
      feed  = create(:feed)
      other = create(:feed)
      create(:feed_item, feed: other, is_read: false)
      expect(feed.unread_count).to eq(0)
    end
  end

  describe '#to_api' do
    it 'includes all expected keys' do
      feed = create(:feed)
      expect(feed.to_api.keys).to include(
        :id, :url, :title, :site_url, :favicon_url,
        :last_fetched_at, :last_error, :fetch_interval_minutes,
        :unread_count, :created_at
      )
    end

    it 'serialises last_fetched_at as iso8601' do
      t    = Time.now
      feed = create(:feed, last_fetched_at: t)
      expect(feed.to_api[:last_fetched_at]).to eq(t.iso8601)
    end

    it 'returns nil for missing timestamps' do
      feed = create(:feed, last_fetched_at: nil)
      expect(feed.to_api[:last_fetched_at]).to be_nil
    end

    it 'reflects current unread_count' do
      feed = create(:feed)
      create(:feed_item, feed: feed, is_read: false)
      expect(feed.to_api[:unread_count]).to eq(1)
    end
  end
end
