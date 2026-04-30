# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/contrib'
require 'json'

require_relative 'db'
require_relative 'models/feed'
require_relative 'models/feed_item'
require_relative 'models/feed_group'
require_relative 'models/feed_group_membership'

module Reader
  class App < Sinatra::Base
    helpers Sinatra::JSON

    configure :development, :production do
      set :show_exceptions, false
      set :raise_errors, false
    end

    configure :test do
      set :show_exceptions, false
      set :raise_errors, true
    end

    before do
      content_type :json
    end

    get '/health' do
      json status: 'ok'
    end

    error Sequel::ValidationFailed do
      status 422
      json error: env['sinatra.error'].message
    end

    error Sequel::NoMatchingRow do
      status 404
      json error: 'Not found'
    end

    error 404 do
      json error: 'Not found'
    end

    error 500 do
      json error: 'Internal server error'
    end
  end
end

# Load route definitions into Reader::App
require_relative 'routes/feeds'
require_relative 'routes/items'
require_relative 'routes/groups'
