# frozen_string_literal: true

require 'sequel'
require 'logger'
require 'sequel/extensions/migration'

# Store timestamps in UTC in SQLite; return them as local Time objects in Ruby
Sequel.database_timezone = :utc
Sequel.application_timezone = :local

db_url = ENV.fetch('DATABASE_URL', "sqlite://#{File.expand_path('../db/development.db', __dir__)}")

DB = Sequel.connect(db_url, loggers: ENV['LOG_LEVEL'] == 'debug' ? [Logger.new($stdout)] : [])
DB.extension(:pagination)
DB.run('PRAGMA foreign_keys = ON') if db_url.start_with?('sqlite')
