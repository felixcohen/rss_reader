# frozen_string_literal: true

require 'rack/test'
require 'factory_bot'
require 'database_cleaner/sequel'
require 'webmock/rspec'

ENV['DATABASE_URL'] = "sqlite://#{File.expand_path('../db/test.db', __dir__)}"
ENV['RACK_ENV'] = 'test'

require_relative '../app/db'
require_relative '../app/models/feed'
require_relative '../app/models/feed_item'
require_relative '../app/models/feed_group'
require_relative '../app/models/feed_group_membership'

# Run migrations on test DB before suite
require 'sequel/extensions/migration'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))
    FactoryBot.find_definitions
    DatabaseCleaner[:sequel, { db: DB }].strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner[:sequel].cleaning { example.run }
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
end

# Time helpers for specs
class Integer
  def hours = self * 3600
  def minutes = self * 60
  def ago = Time.now - self
end
