# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FeedGroup do
  describe 'validations' do
    it 'is valid with a name' do
      expect(FeedGroup.new(name: 'Tech').valid?).to be true
    end

    it 'is invalid without a name' do
      group = FeedGroup.new(name: nil)
      expect(group.valid?).to be false
      expect(group.errors[:name]).not_to be_empty
    end
  end

  describe '#to_api' do
    it 'includes id, name, feed_ids, and created_at' do
      group = create(:feed_group, name: 'Tech')
      expect(group.to_api).to include(id: group.id, name: 'Tech', feed_ids: [])
    end

    it 'lists ids of member feeds' do
      group = create(:feed_group)
      feed  = create(:feed)
      DB[:feed_group_memberships].insert(group_id: group.id, feed_id: feed.id)
      expect(group.to_api[:feed_ids]).to eq([feed.id])
    end

    it 'lists multiple member feed ids' do
      group  = create(:feed_group)
      feed1  = create(:feed)
      feed2  = create(:feed)
      DB[:feed_group_memberships].insert(group_id: group.id, feed_id: feed1.id)
      DB[:feed_group_memberships].insert(group_id: group.id, feed_id: feed2.id)
      expect(group.to_api[:feed_ids]).to match_array([feed1.id, feed2.id])
    end

    it 'does not include feeds from other groups' do
      group1 = create(:feed_group)
      group2 = create(:feed_group)
      feed   = create(:feed)
      DB[:feed_group_memberships].insert(group_id: group2.id, feed_id: feed.id)
      expect(group1.to_api[:feed_ids]).to eq([])
    end

    it 'serialises created_at as iso8601' do
      group = create(:feed_group)
      expect(group.to_api[:created_at]).to match(/\d{4}-\d{2}-\d{2}T/)
    end
  end
end
