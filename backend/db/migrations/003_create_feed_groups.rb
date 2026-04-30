# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_groups) do
      primary_key :id
      String :name, null: false, size: 255
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
