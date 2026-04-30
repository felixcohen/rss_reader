# frozen_string_literal: true

require_relative '../services/feed_fetcher'
require_relative '../services/opml_parser'
require_relative '../services/feed_poller'

module Reader
  class App
    get '/feeds' do
      json Feed.all.map(&:to_api)
    end

    post '/feeds' do
      body = begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 400, json(error: 'Request body must be valid JSON')
      end
      url = body['url']&.strip
      halt 422, json(error: 'url is required') if url.nil? || url.empty?

      result = FeedFetcher.call(url)
      if result[:error]
        halt 422, json(error: result[:error])
      else
        status 201
        json result[:feed].to_api
      end
    end

    delete '/feeds/:id' do
      feed = Feed[params[:id].to_i]
      halt 404, json(error: 'Not found') unless feed

      feed.destroy
      status 204
    end

    get '/feeds/:id/refresh' do
      feed = Feed[params[:id].to_i]
      halt 404, json(error: 'Not found') unless feed

      FeedPoller.poll_one(feed)
      json feed.refresh.to_api
    end

    # Keep export above any GET /feeds/:id to prevent route shadowing
    get '/feeds/export' do
      status 501
      json error: 'not implemented'
    end

    post '/feeds/import' do
      xml = request.body.read
      entries = OpmlParser.call(xml)
      halt 422, json(error: 'Invalid or empty OPML') if entries.empty?

      imported = 0
      errors = []

      entries.each do |entry|
        result = FeedFetcher.call(entry[:url])
        if result[:error]
          errors << { url: entry[:url], error: result[:error] }
          next
        end

        imported += 1
        next unless entry[:group]

        group = FeedGroup.find_or_create(name: entry[:group])
        DB[:feed_group_memberships]
          .insert_conflict(:ignore)
          .insert(feed_id: result[:feed].id, group_id: group.id)
      end

      json imported: imported, errors: errors
    end
  end
end
