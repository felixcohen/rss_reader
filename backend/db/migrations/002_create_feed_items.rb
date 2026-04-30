# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_items) do
      primary_key :id
      foreign_key :feed_id, :feeds, null: false, on_delete: :cascade
      String :guid, null: false, size: 2048
      String :title, size: 1024
      String :url, size: 2048
      String :content_html, text: true
      String :summary, text: true
      String :author, size: 512
      DateTime :published_at
      DateTime :fetched_at, null: false
      TrueClass :is_read, null: false, default: false
      TrueClass :is_starred, null: false, default: false

      index [:feed_id, :guid], unique: true
    end

    # Descending indexes for hot read paths — Sequel DSL can't express DESC per-column
    run 'CREATE INDEX idx_feed_items_feed_published ON feed_items (feed_id, published_at DESC)'
    run 'CREATE INDEX idx_feed_items_read_published ON feed_items (is_read, published_at DESC)'
  end
end
