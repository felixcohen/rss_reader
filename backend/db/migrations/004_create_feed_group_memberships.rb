# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_group_memberships) do
      foreign_key :feed_id, :feeds, null: false, on_delete: :cascade
      foreign_key :group_id, :feed_groups, null: false, on_delete: :cascade
      primary_key [:feed_id, :group_id]
    end
  end
end
