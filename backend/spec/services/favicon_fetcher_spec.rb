# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/favicon_fetcher'

RSpec.describe FaviconFetcher do
  before do
    stub_request(:head, 'https://example.com/favicon.ico')
      .to_return(status: 200, headers: { 'Content-Type' => 'image/gif' })
    stub_request(:head, 'https://nofavicon.example.com/favicon.ico')
      .to_return(status: 404)
  end

  describe '.call' do
    it 'returns the favicon URL when /favicon.ico exists' do
      url = FaviconFetcher.call('https://example.com')
      expect(url).to eq('https://example.com/favicon.ico')
    end

    it 'returns nil when favicon not found' do
      url = FaviconFetcher.call('https://nofavicon.example.com')
      expect(url).to be_nil
    end

    it 'returns nil on connection error' do
      stub_request(:head, 'https://broken.example.com/favicon.ico').to_timeout
      url = FaviconFetcher.call('https://broken.example.com')
      expect(url).to be_nil
    end
  end
end
