# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/feed_poller'

RSpec.describe FeedPoller do
  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  before do
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
    stub_request(:head, 'https://example.com/favicon.ico')
      .to_return(status: 200)
    stub_request(:get, 'https://error.example.com/feed.xml')
      .to_return(status: 500)
  end

  describe '.poll_one' do
    let(:feed) { create(:feed, url: 'https://example.com/feed.xml', last_fetched_at: nil) }

    it 'updates last_fetched_at on success' do
      FeedPoller.poll_one(feed)
      expect(feed.refresh.last_fetched_at).not_to be_nil
    end

    it 'clears last_error on success' do
      feed.update(last_error: 'previous error')
      FeedPoller.poll_one(feed)
      expect(feed.refresh.last_error).to be_nil
    end

    it 'sets favicon_url on first successful poll' do
      FeedPoller.poll_one(feed)
      expect(feed.refresh.favicon_url).not_to be_nil
    end

    it 'does not re-fetch favicon when already set' do
      feed.update(favicon_url: 'https://example.com/favicon.ico')
      FeedPoller.poll_one(feed)
      expect(WebMock).not_to have_requested(:head, 'https://example.com/favicon.ico')
    end

    context 'when fetch fails' do
      let(:feed) { create(:feed, url: 'https://error.example.com/feed.xml') }

      it 'records last_error' do
        FeedPoller.poll_one(feed)
        expect(feed.refresh.last_error).to match(/HTTP 500/)
      end
    end
  end

  describe '.poll_all' do
    it 'polls feeds whose interval has elapsed' do
      due = create(:feed, url: 'https://example.com/feed.xml',
                          last_fetched_at: 2.hours.ago,
                          fetch_interval_minutes: 60)
      not_due = create(:feed, url: 'https://error.example.com/feed.xml',
                              last_fetched_at: 10.minutes.ago,
                              fetch_interval_minutes: 60)

      FeedPoller.poll_all
      expect(due.refresh.last_fetched_at).to be > 1.minutes.ago
      expect(not_due.refresh.last_error).to be_nil
    end

    it 'polls feeds never fetched before' do
      feed = create(:feed, url: 'https://example.com/feed.xml', last_fetched_at: nil)
      FeedPoller.poll_all
      expect(feed.refresh.last_fetched_at).not_to be_nil
    end
  end
end
