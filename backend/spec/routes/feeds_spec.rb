# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/app'

RSpec.describe 'Feeds routes' do
  def app = Reader::App

  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  before do
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
  end

  describe 'GET /feeds' do
    it 'returns empty array when no feeds' do
      get '/feeds'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'returns feeds with unread_count' do
      create(:feed, url: 'https://example.com/feed.xml', title: 'Test')
      get '/feeds'
      body = JSON.parse(last_response.body)
      expect(body.length).to eq(1)
      expect(body.first).to include('id', 'url', 'title', 'unread_count')
    end
  end

  describe 'POST /feeds' do
    it 'fetches and returns the new feed' do
      post '/feeds', JSON.generate(url: 'https://example.com/feed.xml'),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body['url']).to eq('https://example.com/feed.xml')
      expect(body['title']).to eq('Example RSS Feed')
    end

    it 'returns 422 when url missing' do
      post '/feeds', JSON.generate({}), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end

    it 'returns 422 for HTTP error response from feed URL' do
      stub_request(:get, 'https://bad.example.com/feed').to_return(status: 404)
      post '/feeds', JSON.generate(url: 'https://bad.example.com/feed'),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end
  end

  describe 'DELETE /feeds/:id' do
    it 'deletes existing feed and returns 204' do
      feed = create(:feed)
      delete "/feeds/#{feed.id}"
      expect(last_response.status).to eq(204)
      expect(Feed[feed.id]).to be_nil
    end

    it 'returns 404 for unknown feed' do
      delete '/feeds/9999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /feeds/import' do
    let(:opml_body) { File.read(File.join(__dir__, '../fixtures/sample.opml')) }

    before do
      stub_request(:get, 'https://example.com/feed.xml')
        .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, 'https://another.com/rss').to_return(status: 200, body: rss_body)
      stub_request(:get, 'https://ungrouped.com/feed').to_return(status: 200, body: rss_body)
    end

    it 'imports feeds from OPML and returns count' do
      post '/feeds/import', opml_body, 'CONTENT_TYPE' => 'text/xml'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['imported']).to be > 0
    end
  end
end
