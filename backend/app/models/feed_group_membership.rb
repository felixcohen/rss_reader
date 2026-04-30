# frozen_string_literal: true

class FeedGroupMembership < Sequel::Model(:feed_group_memberships)
  many_to_one :feed
  many_to_one :group, class: :FeedGroup
end
