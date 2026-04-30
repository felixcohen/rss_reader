# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/app'

RSpec.describe 'Feed refresh route' do
  def app = Reader::App

  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  describe 'GET /feeds/:id/refresh' do
    let(:feed) { create(:feed, url: 'https://example.com/feed.xml') }

    before do
      stub_request(:get, 'https://example.com/feed.xml')
        .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:head, 'https://example.com/favicon.ico').to_return(status: 200)
    end

    it 'polls the feed and returns updated feed JSON' do
      get "/feeds/#{feed.id}/refresh"
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['id']).to eq(feed.id)
      expect(body['last_fetched_at']).not_to be_nil
    end

    it 'returns 404 for unknown feed' do
      get '/feeds/9999/refresh'
      expect(last_response.status).to eq(404)
    end
  end
end
