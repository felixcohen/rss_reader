# frozen_string_literal: true

module Reader
  class App
    get '/groups' do
      json FeedGroup.all.map(&:to_api)
    end

    post '/groups' do
      body = begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 400, json(error: 'Request body must be valid JSON')
      end
      name = body['name']&.strip
      halt 422, json(error: 'name is required') if name.nil? || name.empty?

      group = FeedGroup.create(name: name)
      status 201
      json group.to_api
    end

    delete '/groups/:id' do
      group = FeedGroup[params[:id].to_i]
      halt 404, json(error: 'Not found') unless group

      group.destroy
      status 204
    end

    post '/groups/:id/feeds' do
      group = FeedGroup[params[:id].to_i]
      halt 404, json(error: 'Group not found') unless group

      body = begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 400, json(error: 'Request body must be valid JSON')
      end
      feed = Feed[body['feed_id'].to_i]
      halt 404, json(error: 'Feed not found') unless feed

      DB[:feed_group_memberships]
        .insert_conflict(:ignore)
        .insert(feed_id: feed.id, group_id: group.id)
      json group.refresh.to_api
    end
  end
end
