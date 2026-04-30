# frozen_string_literal: true

require_relative 'app/app'
require_relative 'app/services/feed_poller'
require 'rufus-scheduler'

use Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'http://localhost:5173')
    resource '*', headers: :any, methods: %i[get post patch delete options]
  end
end

# Start background poller — only in non-test environments
unless ENV['RACK_ENV'] == 'test'
  scheduler = Rufus::Scheduler.new
  scheduler.every '1m', overlap: false do
    FeedPoller.poll_all
  rescue StandardError => e
    warn "Poller error: #{e.message}"
  end
end

run Reader::App
