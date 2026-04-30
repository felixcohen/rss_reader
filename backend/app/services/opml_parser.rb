# frozen_string_literal: true

require 'nokogiri'

class OpmlParser
  def self.call(xml_body)
    new(xml_body).call
  end

  def initialize(xml_body)
    @xml_body = xml_body
  end

  def call
    doc = Nokogiri::XML(@xml_body) { |c| c.strict }
    return [] if doc.errors.any?

    feeds = []
    doc.css('body > outline').each do |node|
      if node['xmlUrl']
        feeds << build_entry(node, nil)
      else
        group_name = node['title'] || node['text']
        node.css('outline[xmlUrl]').each do |child|
          feeds << build_entry(child, group_name)
        end
      end
    end
    feeds
  rescue Nokogiri::XML::SyntaxError
    []
  end

  private

  def build_entry(node, group)
    {
      url: node['xmlUrl'],
      title: node['title'] || node['text'],
      site_url: node['htmlUrl'],
      group: group
    }
  end
end
