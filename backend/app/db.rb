# frozen_string_literal: true

require 'sequel'
require 'logger'
require 'sequel/extensions/migration'

db_url = ENV.fetch('DATABASE_URL', "sqlite://#{File.expand_path('../db/development.db', __dir__)}")

DB = Sequel.connect(db_url, loggers: ENV['LOG_LEVEL'] == 'debug' ? [Logger.new($stdout)] : [])
DB.extension(:pagination)
