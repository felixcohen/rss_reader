# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../app/app'

RSpec.describe 'OPML export route' do
  def app = Reader::App

  before do
    create(:feed, url: 'https://example.com/feed', title: 'Example', site_url: 'https://example.com')
  end

  describe 'GET /feeds/export' do
    it 'returns 200' do
      get '/feeds/export'
      expect(last_response.status).to eq(200)
    end

    it 'sets content type to text/xml' do
      get '/feeds/export'
      expect(last_response.content_type).to include('text/xml')
    end

    it 'sets content-disposition attachment with filename' do
      get '/feeds/export'
      expect(last_response.headers['Content-Disposition']).to include('attachment')
      expect(last_response.headers['Content-Disposition']).to include('feeds.opml')
    end

    it 'returns valid OPML XML' do
      get '/feeds/export'
      doc = Nokogiri::XML(last_response.body) { |c| c.strict }
      expect(doc.errors).to be_empty
      expect(doc.root.name).to eq('opml')
    end

    it 'contains the feed in the export' do
      get '/feeds/export'
      doc = Nokogiri::XML(last_response.body)
      expect(doc.at_css("outline[xmlUrl='https://example.com/feed']")).not_to be_nil
    end
  end
end
