# frozen_string_literal: true

class FeedGroup < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  many_to_many :feeds,
    join_table: :feed_group_memberships,
    left_key: :group_id,
    right_key: :feed_id

  def validate
    super
    validates_presence :name
  end

  def to_api
    {
      id: id,
      name: name,
      feed_ids: feeds_dataset.select_map(:id),
      created_at: created_at&.iso8601
    }
  end
end
