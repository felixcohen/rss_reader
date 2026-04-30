# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/app'

RSpec.describe 'Items routes' do
  def app = Reader::App

  let(:feed)  { create(:feed) }
  let(:feed2) { create(:feed, url: 'https://feed2.example.com/rss') }

  let!(:item1) do
    create(:feed_item, feed: feed, published_at: Time.now - 3600, is_read: false)
  end
  let!(:item2) do
    create(:feed_item, feed: feed, published_at: Time.now - 7200, is_read: true)
  end
  let!(:item3) do
    create(:feed_item, feed: feed2, published_at: Time.now - 100, is_read: false)
  end

  describe 'GET /items' do
    it 'returns all items newest first when no filters' do
      get '/items'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      ids = body['items'].map { _1['id'] }
      expect(ids).to eq([item3.id, item1.id, item2.id])
    end

    it 'filters by feed_id' do
      get "/items?feed_id=#{feed.id}"
      body = JSON.parse(last_response.body)
      expect(body['items'].map { _1['id'] }).to contain_exactly(item1.id, item2.id)
    end

    it 'filters unread only' do
      get "/items?unread_only=true"
      body = JSON.parse(last_response.body)
      ids = body['items'].map { _1['id'] }
      expect(ids).to include(item1.id, item3.id)
      expect(ids).not_to include(item2.id)
    end

    it 'paginates with limit' do
      get '/items?limit=2'
      body = JSON.parse(last_response.body)
      expect(body['items'].length).to eq(2)
    end

    it 'supports before_id cursor pagination' do
      get '/items?limit=1'
      first_body = JSON.parse(last_response.body)
      last_id = first_body['items'].last['id']

      get "/items?limit=2&before_id=#{last_id}"
      second_body = JSON.parse(last_response.body)
      expect(second_body['items'].map { _1['id'] }).not_to include(item3.id)
    end

    it 'filters by group_id' do
      group = create(:feed_group)
      DB[:feed_group_memberships].insert(feed_id: feed.id, group_id: group.id)

      get "/items?group_id=#{group.id}"
      body = JSON.parse(last_response.body)
      ids = body['items'].map { _1['id'] }
      expect(ids).to include(item1.id, item2.id)
      expect(ids).not_to include(item3.id)
    end

    it 'returns next_before_id when more items exist' do
      get '/items?limit=1'
      body = JSON.parse(last_response.body)
      expect(body['next_before_id']).not_to be_nil
    end

    it 'returns null next_before_id on last page' do
      get '/items?limit=100'
      body = JSON.parse(last_response.body)
      expect(body['next_before_id']).to be_nil
    end

    it 'includes expected fields on each item' do
      get '/items?limit=1'
      item = JSON.parse(last_response.body)['items'].first
      expect(item.keys).to include('id', 'feed_id', 'title', 'url', 'is_read', 'is_starred', 'published_at')
    end
  end

  describe 'GET /items/all' do
    it 'returns all items across all feeds' do
      get '/items/all'
      expect(last_response.status).to eq(200)
      ids = JSON.parse(last_response.body)['items'].map { _1['id'] }
      expect(ids).to include(item1.id, item2.id, item3.id)
    end
  end

  describe 'PATCH /items/:id' do
    it 'marks item as read' do
      patch "/items/#{item1.id}", JSON.generate(is_read: true),
            'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(item1.refresh.is_read).to be(true)
    end

    it 'stars an item' do
      patch "/items/#{item1.id}", JSON.generate(is_starred: true),
            'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(item1.refresh.is_starred).to be(true)
    end

    it 'returns updated item' do
      patch "/items/#{item1.id}", JSON.generate(is_read: true),
            'CONTENT_TYPE' => 'application/json'
      body = JSON.parse(last_response.body)
      expect(body['is_read']).to be(true)
    end

    it 'returns 404 for unknown item' do
      patch '/items/9999', JSON.generate(is_read: true), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(404)
    end

    it 'ignores unknown fields' do
      patch "/items/#{item1.id}", JSON.generate(is_read: true, title: 'hacked'),
            'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(item1.refresh.title).not_to eq('hacked')
    end
  end

  describe 'POST /items/mark-all-read' do
    it 'marks all unread items as read with no filter' do
      post '/items/mark-all-read'
      expect(last_response.status).to eq(200)
      expect(FeedItem.where(is_read: false).count).to eq(0)
    end

    it 'marks only items in given feed as read' do
      post "/items/mark-all-read?feed_id=#{feed.id}"
      expect(item1.refresh.is_read).to be(true)
      expect(item3.refresh.is_read).to be(false)
    end

    it 'marks only items in given group as read' do
      group = create(:feed_group)
      DB[:feed_group_memberships].insert(feed_id: feed.id, group_id: group.id)
      post "/items/mark-all-read?group_id=#{group.id}"
      expect(item1.refresh.is_read).to be(true)
      expect(item3.refresh.is_read).to be(false)
    end

    it 'returns count of items marked' do
      post '/items/mark-all-read'
      body = JSON.parse(last_response.body)
      expect(body['marked']).to be_a(Integer)
      expect(body['marked']).to be >= 2
    end
  end
end
