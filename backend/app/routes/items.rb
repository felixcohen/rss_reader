# frozen_string_literal: true

module Reader
  class App
    DEFAULT_LIMIT = 50
    MAX_LIMIT     = 200

    get '/items' do
      limit     = params[:limit] ? [[params[:limit].to_i, 1].max, MAX_LIMIT].min : DEFAULT_LIMIT
      before_id = params[:before_id]&.to_i
      feed_id   = params[:feed_id]&.to_i
      group_id  = params[:group_id]&.to_i
      unread    = params[:unread_only]  == 'true'
      starred   = params[:starred_only] == 'true'

      ds = FeedItem.order(Sequel.desc(:published_at), Sequel.desc(:id))

      if group_id && group_id > 0
        feed_ids = FeedGroupMembership.where(group_id: group_id).select_map(:feed_id)
        ds = ds.where(feed_id: feed_ids)
      elsif feed_id && feed_id > 0
        ds = ds.where(feed_id: feed_id)
      end

      ds = ds.where(is_read: false)    if unread
      ds = ds.where(is_starred: true)  if starred
      ds = ds.where { id < before_id } if before_id && before_id > 0

      items    = ds.limit(limit + 1).all
      has_more = items.length > limit
      items    = items.first(limit)

      next_before_id = has_more ? items.last&.id : nil

      json items: items.map(&:to_api), next_before_id: next_before_id
    end

    get '/items/all' do
      limit     = params[:limit] ? [[params[:limit].to_i, 1].max, MAX_LIMIT].min : DEFAULT_LIMIT
      before_id = params[:before_id]&.to_i
      unread    = params[:unread_only] == 'true'

      ds = FeedItem.order(Sequel.desc(:published_at), Sequel.desc(:id))
      ds = ds.where(is_read: false) if unread
      ds = ds.where { id < before_id } if before_id && before_id > 0

      items    = ds.limit(limit + 1).all
      has_more = items.length > limit
      items    = items.first(limit)

      next_before_id = has_more ? items.last&.id : nil

      json items: items.map(&:to_api), next_before_id: next_before_id
    end

    patch '/items/:id' do
      item = FeedItem[params[:id].to_i]
      halt 404, json(error: 'Not found') unless item

      body = begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 400, json(error: 'Request body must be valid JSON')
      end

      updates = {}
      updates[:is_read]    = body['is_read']    unless body['is_read'].nil?
      updates[:is_starred] = body['is_starred'] unless body['is_starred'].nil?

      item.update(updates) unless updates.empty?
      json item.refresh.to_api
    end

    post '/items/mark-all-read' do
      feed_id  = params[:feed_id]&.to_i
      group_id = params[:group_id]&.to_i

      ds = FeedItem.where(is_read: false)

      if group_id && group_id > 0
        feed_ids = FeedGroupMembership.where(group_id: group_id).select_map(:feed_id)
        ds = ds.where(feed_id: feed_ids)
      elsif feed_id && feed_id > 0
        ds = ds.where(feed_id: feed_id)
      end

      marked = ds.update(is_read: true)
      json marked: marked
    end
  end
end
