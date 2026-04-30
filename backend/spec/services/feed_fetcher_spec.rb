# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/feed_fetcher'

RSpec.describe FeedFetcher do
  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }
  let(:atom_body) { File.read(File.join(__dir__, '../fixtures/atom.xml')) }

  before do
    WebMock.enable!
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
    stub_request(:get, 'https://atom.example.com/feed')
      .to_return(status: 200, body: atom_body, headers: { 'Content-Type' => 'application/atom+xml' })
    stub_request(:get, 'https://notfound.example.com/feed').to_return(status: 404)
    stub_request(:get, 'https://timeout.example.com/feed').to_timeout
  end

  describe '.call' do
    context 'with valid RSS 2.0 feed' do
      it 'creates a Feed record' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed]).to be_a(Feed)
        expect(Feed[url: 'https://example.com/feed.xml']).not_to be_nil
      end

      it 'sets feed title and site_url from parsed feed' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed].title).to eq('Example RSS Feed')
        expect(result[:feed].site_url).to eq('https://example.com')
      end

      it 'creates FeedItem records for each entry' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed].feed_items.count).to eq(2)
      end

      it 'sets item fields correctly' do
        FeedFetcher.call('https://example.com/feed.xml')
        item = FeedItem.first(guid: 'https://example.com/1')
        expect(item.title).to eq('First Post')
        expect(item.url).to eq('https://example.com/1')
        expect(item.is_read).to be(false)
      end

      it 'sanitises item content_html' do
        FeedFetcher.call('https://example.com/feed.xml')
        item = FeedItem.first(guid: 'https://example.com/1')
        expect(item.content_html).to include('<p>')
        expect(item.content_html).not_to include('<script')
      end
    end

    context 'with valid Atom feed' do
      it 'creates a Feed and items' do
        result = FeedFetcher.call('https://atom.example.com/feed')
        expect(result[:feed]).to be_a(Feed)
        expect(result[:feed].feed_items.count).to eq(1)
      end
    end

    context 'with HTTP error' do
      it 'returns error hash without persisting' do
        result = FeedFetcher.call('https://notfound.example.com/feed')
        expect(result[:error]).to match(/HTTP 404/)
        expect(Feed.count).to eq(0)
      end
    end

    context 'with network timeout' do
      it 'returns error hash' do
        result = FeedFetcher.call('https://timeout.example.com/feed')
        expect(result[:error]).to be_a(String)
      end
    end

    context 'when feed URL already exists' do
      it 'returns the existing feed without duplication' do
        FeedFetcher.call('https://example.com/feed.xml')
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed]).to be_a(Feed)
        expect(Feed.count).to eq(1)
      end
    end
  end
end
