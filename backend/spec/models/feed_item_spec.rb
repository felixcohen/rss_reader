# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FeedItem do
  let(:feed) { create(:feed) }

  describe 'validations' do
    it 'is valid with required fields' do
      expect(FeedItem.new(feed_id: feed.id, guid: 'abc', fetched_at: Time.now).valid?).to be true
    end

    it 'is invalid without feed_id' do
      item = FeedItem.new(guid: 'abc', fetched_at: Time.now)
      expect(item.valid?).to be false
      expect(item.errors[:feed_id]).not_to be_empty
    end

    it 'is invalid without guid' do
      item = FeedItem.new(feed_id: feed.id, fetched_at: Time.now)
      expect(item.valid?).to be false
      expect(item.errors[:guid]).not_to be_empty
    end

    it 'is invalid without fetched_at' do
      item = FeedItem.new(feed_id: feed.id, guid: 'abc')
      expect(item.valid?).to be false
      expect(item.errors[:fetched_at]).not_to be_empty
    end
  end

  describe '#to_api' do
    it 'includes all expected keys' do
      item = create(:feed_item, feed: feed)
      expect(item.to_api.keys).to include(
        :id, :feed_id, :guid, :title, :url,
        :content_html, :summary, :author,
        :published_at, :fetched_at, :is_read, :is_starred
      )
    end

    it 'serialises boolean flags correctly' do
      item = create(:feed_item, feed: feed, is_read: true, is_starred: false)
      expect(item.to_api[:is_read]).to be true
      expect(item.to_api[:is_starred]).to be false
    end

    it 'serialises published_at as iso8601' do
      t    = Time.now - 3600
      item = create(:feed_item, feed: feed, published_at: t)
      expect(item.to_api[:published_at]).to eq(t.iso8601)
    end

    it 'returns nil published_at when not set' do
      item = create(:feed_item, feed: feed, published_at: nil)
      expect(item.to_api[:published_at]).to be_nil
    end

    it 'reflects the correct feed_id' do
      item = create(:feed_item, feed: feed)
      expect(item.to_api[:feed_id]).to eq(feed.id)
    end
  end
end
