# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feeds) do
      primary_key :id
      String :url, null: false, unique: true, size: 2048
      String :title, size: 512
      String :site_url, size: 2048
      String :description, text: true
      String :favicon_url, size: 2048
      DateTime :last_fetched_at
      Integer :fetch_interval_minutes, default: 60, null: false
      String :last_error, text: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
