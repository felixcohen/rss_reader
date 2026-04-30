# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../app/services/opml_exporter'

RSpec.describe OpmlExporter do
  let(:group) { create(:feed_group, name: 'Tech') }
  let(:feed_in_group) do
    create(:feed, url: 'https://tech.example.com/feed', title: 'Tech Blog',
                  site_url: 'https://tech.example.com')
  end
  let(:ungrouped_feed) do
    create(:feed, url: 'https://other.example.com/feed', title: 'Other Blog',
                  site_url: 'https://other.example.com')
  end

  before do
    DB[:feed_group_memberships].insert(feed_id: feed_in_group.id, group_id: group.id)
    ungrouped_feed
  end

  describe '.call' do
    subject(:xml_string) { OpmlExporter.call }

    it 'returns a string' do
      expect(xml_string).to be_a(String)
    end

    it 'is valid XML' do
      doc = Nokogiri::XML(xml_string) { |c| c.strict }
      expect(doc.errors).to be_empty
    end

    it 'has opml root with version 2.0' do
      doc = Nokogiri::XML(xml_string)
      expect(doc.root.name).to eq('opml')
      expect(doc.root['version']).to eq('2.0')
    end

    it 'includes a group outline for named groups' do
      doc = Nokogiri::XML(xml_string)
      group_node = doc.at_css("outline[text='Tech']")
      expect(group_node).not_to be_nil
    end

    it 'nests grouped feed under its group outline' do
      doc = Nokogiri::XML(xml_string)
      group_node = doc.at_css("outline[text='Tech']")
      feed_node  = group_node&.at_css("outline[xmlUrl='https://tech.example.com/feed']")
      expect(feed_node).not_to be_nil
    end

    it 'places ungrouped feeds at the body level' do
      doc = Nokogiri::XML(xml_string)
      body = doc.at_css('body')
      ungrouped = body.children.find do |node|
        node['xmlUrl'] == 'https://other.example.com/feed'
      end
      expect(ungrouped).not_to be_nil
    end

    it 'sets type="rss" on feed outlines' do
      doc = Nokogiri::XML(xml_string)
      feed_node = doc.at_css("outline[xmlUrl='https://tech.example.com/feed']")
      expect(feed_node['type']).to eq('rss')
    end

    it 'handles no feeds gracefully' do
      DB[:feed_group_memberships].delete
      FeedGroup.dataset.delete
      Feed.dataset.delete

      doc = Nokogiri::XML(OpmlExporter.call) { |c| c.strict }
      expect(doc.errors).to be_empty
      expect(doc.css('body outline').length).to eq(0)
    end
  end
end
