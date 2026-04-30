# frozen_string_literal: true

require 'set'
require 'nokogiri'

class OpmlExporter
  def self.call
    new.call
  end

  def call
    all_feeds    = Feed.all
    feeds_by_id  = all_feeds.each_with_object({}) { |f, h| h[f.id] = f }

    memberships_by_group = FeedGroupMembership.all.group_by(&:group_id)
    grouped_feed_ids     = Set.new(memberships_by_group.values.flatten.map(&:feed_id))

    groups    = FeedGroup.all
    ungrouped = all_feeds.reject { |f| grouped_feed_ids.include?(f.id) }

    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.opml(version: '2.0') do
        xml.head { xml.title 'RSS Reader Export' }
        xml.body do
          groups.each do |group|
            member_ids = (memberships_by_group[group.id] || []).map(&:feed_id)
            xml.outline(text: group.name, title: group.name) do
              member_ids.each do |fid|
                feed = feeds_by_id[fid]
                next unless feed

                xml.outline(
                  type:    'rss',
                  text:    feed.title || feed.url,
                  title:   feed.title || feed.url,
                  xmlUrl:  feed.url,
                  htmlUrl: feed.site_url || ''
                )
              end
            end
          end

          ungrouped.each do |feed|
            xml.outline(
              type:    'rss',
              text:    feed.title || feed.url,
              title:   feed.title || feed.url,
              xmlUrl:  feed.url,
              htmlUrl: feed.site_url || ''
            )
          end
        end
      end
    end

    builder.to_xml
  end
end
