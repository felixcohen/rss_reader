# frozen_string_literal: true

class FeedItem < Sequel::Model
  plugin :validation_helpers

  many_to_one :feed

  def validate
    super
    validates_presence %i[feed_id guid fetched_at]
  end

  def to_api
    {
      id: id,
      feed_id: feed_id,
      guid: guid,
      title: title,
      url: url,
      content_html: content_html,
      summary: summary,
      author: author,
      published_at: published_at&.iso8601,
      fetched_at: fetched_at.iso8601,
      is_read: is_read,
      is_starred: is_starred
    }
  end
end
