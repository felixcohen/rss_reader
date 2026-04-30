# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/app'

RSpec.describe 'Groups routes' do
  def app = Reader::App

  describe 'GET /groups' do
    it 'returns empty array' do
      get '/groups'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end
  end

  describe 'POST /groups' do
    it 'creates a group' do
      post '/groups', JSON.generate(name: 'Tech'), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body['name']).to eq('Tech')
    end

    it 'returns 422 when name missing' do
      post '/groups', JSON.generate({}), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end
  end

  describe 'DELETE /groups/:id' do
    it 'deletes group and returns 204' do
      group = create(:feed_group)
      delete "/groups/#{group.id}"
      expect(last_response.status).to eq(204)
    end

    it 'returns 404 for unknown group' do
      delete '/groups/9999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /groups/:id/feeds' do
    it 'adds feed to group' do
      group = create(:feed_group)
      feed = create(:feed)
      post "/groups/#{group.id}/feeds", JSON.generate(feed_id: feed.id),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(FeedGroupMembership[feed_id: feed.id, group_id: group.id]).not_to be_nil
    end
  end
end
