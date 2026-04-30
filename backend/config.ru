# frozen_string_literal: true

require_relative 'app/app'

use Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'http://localhost:5173')
    resource '*', headers: :any, methods: %i[get post patch delete options]
  end
end

run Reader::App
