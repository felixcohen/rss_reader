# frozen_string_literal: true

class Feed < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  one_to_many :feed_items, order: Sequel.desc(:published_at)
  many_to_many :groups,
    class: :FeedGroup,
    join_table: :feed_group_memberships,
    left_key: :feed_id,
    right_key: :group_id

  def validate
    super
    validates_presence :url
    validates_unique :url
    validates_min_length 1, :url
  end

  def unread_count
    feed_items_dataset.where(is_read: false).count
  end

  def to_api
    {
      id: id,
      url: url,
      title: title,
      site_url: site_url,
      favicon_url: favicon_url,
      last_fetched_at: last_fetched_at&.iso8601,
      last_error: last_error,
      fetch_interval_minutes: fetch_interval_minutes,
      unread_count: unread_count,
      created_at: created_at.iso8601
    }
  end
end
