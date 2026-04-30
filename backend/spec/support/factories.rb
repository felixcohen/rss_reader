# frozen_string_literal: true

FactoryBot.define do
  factory :feed do
    sequence(:url) { |n| "https://example#{n}.com/feed.xml" }
    title { 'Example Feed' }
    site_url { 'https://example.com' }
    fetch_interval_minutes { 60 }
    created_at { Time.now }
    updated_at { Time.now }
  end

  factory :feed_item do
    association :feed
    sequence(:guid) { |n| "guid-#{n}" }
    title { 'Test Item' }
    url { 'https://example.com/item/1' }
    content_html { '<p>Content</p>' }
    summary { 'Summary text' }
    published_at { Time.now - 3600 }
    fetched_at { Time.now }
    is_read { false }
    is_starred { false }
  end

  factory :feed_group do
    sequence(:name) { |n| "Group #{n}" }
    created_at { Time.now }
    updated_at { Time.now }
  end
end
