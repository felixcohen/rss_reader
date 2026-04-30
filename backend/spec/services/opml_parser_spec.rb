# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/services/opml_parser'

RSpec.describe OpmlParser do
  let(:opml_body) { File.read(File.join(__dir__, '../fixtures/sample.opml')) }

  describe '.call' do
    it 'returns array of feed hashes' do
      result = OpmlParser.call(opml_body)
      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end

    it 'extracts xmlUrl and title' do
      result = OpmlParser.call(opml_body)
      urls = result.map { _1[:url] }
      expect(urls).to include('https://example.com/feed.xml')
      expect(urls).to include('https://another.com/rss')
      expect(urls).to include('https://ungrouped.com/feed')
    end

    it 'includes group name for grouped feeds' do
      result = OpmlParser.call(opml_body)
      tech_feeds = result.select { _1[:group] == 'Tech' }
      expect(tech_feeds.length).to eq(2)
    end

    it 'returns nil group for ungrouped feeds' do
      result = OpmlParser.call(opml_body)
      ungrouped = result.find { _1[:url] == 'https://ungrouped.com/feed' }
      expect(ungrouped[:group]).to be_nil
    end

    it 'returns empty array for invalid XML' do
      result = OpmlParser.call('not xml at all')
      expect(result).to eq([])
    end
  end
end
