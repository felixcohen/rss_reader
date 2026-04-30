# Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a runnable monorepo skeleton with database migrations, Sequel models, a passing smoke test, and Docker configs — ready for feature branches to build on.

**Architecture:** Sinatra modular app (one `Reader::App < Sinatra::Base` class, routes added from separate files). Sequel ORM connects to SQLite. rufus-scheduler will be wired in feed-polling plan. Backend in `backend/`, React/Vite frontend scaffold in `frontend/`.

**Tech Stack:** Ruby 3.3 (rbenv/.ruby-version), Sinatra 3, Sequel 5, SQLite3, RSpec, Rack::Test, FactoryBot, DatabaseCleaner-Sequel, Node 20 / Vite 5 / React 18

---

## File Map

```
backend/
  .ruby-version                      # "3.3.4"
  Gemfile                            # all gem declarations
  Gemfile.lock                       # committed
  Rakefile                           # db:migrate, db:reset, spec tasks
  config.ru                          # Rack entry point
  .rubocop.yml                       # rubocop config
  app/
    app.rb                           # Reader::App class + error handlers
    db.rb                            # Sequel.connect, migration helper
    models/
      feed.rb                        # Feed < Sequel::Model
      feed_item.rb                   # FeedItem < Sequel::Model
      feed_group.rb                  # FeedGroup < Sequel::Model
      feed_group_membership.rb       # FeedGroupMembership < Sequel::Model
    routes/
      feeds.rb                       # stub GET /feeds, POST /feeds, DELETE /feeds/:id
      items.rb                       # stub GET /items
      groups.rb                      # stub POST /groups, DELETE /groups/:id
  db/
    migrations/
      001_create_feeds.rb
      002_create_feed_items.rb
      003_create_feed_groups.rb
      004_create_feed_group_memberships.rb
    development.db                   # gitignored
    test.db                          # gitignored
  spec/
    spec_helper.rb                   # RSpec + Rack::Test + DB + FactoryBot setup
    support/
      factories.rb                   # FactoryBot factories
    routes/
      health_spec.rb                 # smoke test
  Dockerfile                         # multi-stage Ruby image

frontend/
  package.json                       # React + Vite deps
  vite.config.js
  index.html
  src/
    main.jsx
    App.jsx
  Dockerfile                         # multi-stage nginx image
  nginx.conf                         # proxies /api/* to backend

docker-compose.yml                   # production-style
docker-compose.dev.yml               # dev overrides (hot reload)
.env.example
.gitignore
```

---

## Task 1: Monorepo skeleton + Ruby version

**Files:** Create `backend/.ruby-version`, `backend/Gemfile`, `.gitignore`, `.env.example`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p backend/app/{models,routes,services} \
         backend/db/migrations \
         backend/spec/{support,routes,models,services} \
         frontend/src
```

- [ ] **Step 2: Write `backend/.ruby-version`**

```
3.3.4
```

- [ ] **Step 3: Write `backend/Gemfile`**

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.3.4'

gem 'sinatra', '~> 3.2'
gem 'sinatra-contrib', '~> 3.2'
gem 'puma', '~> 6.4'
gem 'sequel', '~> 5.80'
gem 'sqlite3', '~> 2.0'
gem 'feedjira', '~> 3.2'
gem 'nokogiri', '~> 1.16'
gem 'loofah', '~> 2.22'
gem 'rufus-scheduler', '~> 3.9'
gem 'rack-cors', '~> 2.0'
gem 'oj', '~> 3.16'

group :development, :test do
  gem 'rspec', '~> 3.13'
  gem 'rack-test', '~> 2.1'
  gem 'factory_bot', '~> 6.4'
  gem 'webmock', '~> 3.23'
  gem 'database_cleaner-sequel', '~> 2.0'
  gem 'rerun', '~> 0.14'
end

group :development do
  gem 'rubocop', '~> 1.65', require: false
  gem 'rubocop-sequel', '~> 0.3', require: false
  gem 'rubocop-rspec', '~> 3.0', require: false
end
```

- [ ] **Step 4: Install gems**

```bash
cd backend && bundle install
```

Expected: Gemfile.lock created, no errors.

- [ ] **Step 5: Write `.gitignore` (repo root)**

```
# Ruby
backend/.bundle/
backend/vendor/bundle
backend/db/*.db
backend/tmp/

# Node
frontend/node_modules/
frontend/dist/

# Env
.env

# System
.DS_Store
```

- [ ] **Step 6: Write `.env.example` (repo root)**

```bash
# Secret key — generate with: ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
SECRET_KEY=change_me_in_production

# Feed polling interval in minutes (default: 60)
POLL_INTERVAL_DEFAULT_MINUTES=60

# Max items stored per feed (older items pruned beyond this)
MAX_ITEMS_PER_FEED=500

# Log level: debug | info | warn | error
LOG_LEVEL=info

# Database path — defaults to backend/db/development.db
DATABASE_URL=sqlite://db/development.db
```

- [ ] **Step 7: Commit**

```bash
git init
git add .gitignore .env.example backend/.ruby-version backend/Gemfile backend/Gemfile.lock
git commit -m "chore: init monorepo skeleton with Gemfile"
```

---

## Task 2: Database module + Rakefile

**Files:** Create `backend/app/db.rb`, `backend/Rakefile`

- [ ] **Step 1: Write `backend/app/db.rb`**

```ruby
# frozen_string_literal: true

require 'sequel'
require 'logger'
require 'sequel/extensions/migration'

db_url = ENV.fetch('DATABASE_URL', "sqlite://#{File.expand_path('../db/development.db', __dir__)}")

DB = Sequel.connect(db_url, loggers: ENV['LOG_LEVEL'] == 'debug' ? [Logger.new($stdout)] : [])
DB.extension(:pagination)
```

- [ ] **Step 2: Write `backend/Rakefile`**

```ruby
# frozen_string_literal: true

require 'sequel'
require 'sequel/extensions/migration'

MIGRATIONS_DIR = File.expand_path('db/migrations', __dir__)

namespace :db do
  desc 'Run pending migrations'
  task :migrate do
    url = ENV.fetch('DATABASE_URL', "sqlite://#{File.expand_path('db/development.db', __dir__)}")
    Sequel.connect(url) do |db|
      Sequel::Migrator.run(db, MIGRATIONS_DIR)
      puts "Migrated #{url}"
    end
  end

  desc 'Migrate test database'
  task :migrate_test do
    url = "sqlite://#{File.expand_path('db/test.db', __dir__)}"
    Sequel.connect(url) do |db|
      Sequel::Migrator.run(db, MIGRATIONS_DIR)
      puts "Migrated #{url}"
    end
  end

  desc 'Drop and recreate development DB'
  task :reset do
    path = File.expand_path('db/development.db', __dir__)
    FileUtils.rm_f(path)
    Rake::Task['db:migrate'].invoke
  end
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task default: :spec
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/db.rb backend/Rakefile
git commit -m "chore: add DB connection module and Rake tasks"
```

---

## Task 3: Migrations

**Files:** Create `backend/db/migrations/001_create_feeds.rb` through `004_create_feed_group_memberships.rb`

- [ ] **Step 1: Write `001_create_feeds.rb`**

```ruby
# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feeds) do
      primary_key :id
      String :url, null: false, unique: true, size: 2048
      String :title, size: 512
      String :site_url, size: 2048
      String :description, text: true
      String :favicon_url, size: 2048
      DateTime :last_fetched_at
      Integer :fetch_interval_minutes, default: 60, null: false
      String :last_error, text: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
```

- [ ] **Step 2: Write `002_create_feed_items.rb`**

```ruby
# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_items) do
      primary_key :id
      foreign_key :feed_id, :feeds, null: false, on_delete: :cascade
      String :guid, null: false, size: 2048
      String :title, size: 1024
      String :url, size: 2048
      String :content_html, text: true
      String :summary, text: true
      String :author, size: 512
      DateTime :published_at
      DateTime :fetched_at, null: false
      TrueClass :is_read, null: false, default: false
      TrueClass :is_starred, null: false, default: false

      index [:feed_id, :guid], unique: true
    end

    # Descending indexes for the hot read paths — Sequel DSL can't express DESC per-column
    run 'CREATE INDEX idx_feed_items_feed_published ON feed_items (feed_id, published_at DESC)'
    run 'CREATE INDEX idx_feed_items_read_published ON feed_items (is_read, published_at DESC)'
    end
  end
end
```

- [ ] **Step 3: Write `003_create_feed_groups.rb`**

```ruby
# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_groups) do
      primary_key :id
      String :name, null: false, size: 255
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
```

- [ ] **Step 4: Write `004_create_feed_group_memberships.rb`**

```ruby
# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feed_group_memberships) do
      foreign_key :feed_id, :feeds, null: false, on_delete: :cascade
      foreign_key :group_id, :feed_groups, null: false, on_delete: :cascade
      primary_key [:feed_id, :group_id]
    end
  end
end
```

- [ ] **Step 5: Run migrations against dev DB**

```bash
cd backend && bundle exec rake db:migrate
```

Expected: `Migrated sqlite://db/development.db` — no errors.

- [ ] **Step 6: Run migrations against test DB**

```bash
cd backend && bundle exec rake db:migrate_test
```

- [ ] **Step 7: Commit**

```bash
git add backend/db/migrations/
git commit -m "feat: add DB migrations for feeds, items, groups"
```

---

## Task 4: Sequel models

**Files:** Create `backend/app/models/feed.rb`, `feed_item.rb`, `feed_group.rb`, `feed_group_membership.rb`

- [ ] **Step 1: Write `backend/app/models/feed.rb`**

```ruby
# frozen_string_literal: true

class Feed < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  one_to_many :feed_items, order: Sequel.desc(:published_at)
  many_to_many :groups,
    class: :FeedGroup,
    join_table: :feed_group_memberships,
    left_key: :feed_id,
    right_key: :group_id

  def validate
    super
    validates_presence :url
    validates_unique :url
    validates_min_length 1, :url
  end

  def unread_count
    feed_items_dataset.where(is_read: false).count
  end

  def to_api
    {
      id: id,
      url: url,
      title: title,
      site_url: site_url,
      favicon_url: favicon_url,
      last_fetched_at: last_fetched_at&.iso8601,
      last_error: last_error,
      fetch_interval_minutes: fetch_interval_minutes,
      unread_count: unread_count,
      created_at: created_at.iso8601
    }
  end
end
```

- [ ] **Step 2: Write `backend/app/models/feed_item.rb`**

```ruby
# frozen_string_literal: true

class FeedItem < Sequel::Model
  plugin :validation_helpers

  many_to_one :feed

  def validate
    super
    validates_presence %i[feed_id guid fetched_at]
  end

  def to_api
    {
      id: id,
      feed_id: feed_id,
      guid: guid,
      title: title,
      url: url,
      content_html: content_html,
      summary: summary,
      author: author,
      published_at: published_at&.iso8601,
      fetched_at: fetched_at.iso8601,
      is_read: is_read,
      is_starred: is_starred
    }
  end
end
```

- [ ] **Step 3: Write `backend/app/models/feed_group.rb`**

```ruby
# frozen_string_literal: true

class FeedGroup < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  many_to_many :feeds,
    join_table: :feed_group_memberships,
    left_key: :group_id,
    right_key: :feed_id

  def validate
    super
    validates_presence :name
  end

  def to_api
    {
      id: id,
      name: name,
      feed_ids: feeds_dataset.select_map(:id),
      created_at: created_at.iso8601
    }
  end
end
```

- [ ] **Step 4: Write `backend/app/models/feed_group_membership.rb`**

```ruby
# frozen_string_literal: true

class FeedGroupMembership < Sequel::Model(:feed_group_memberships)
  many_to_one :feed
  many_to_one :group, class: :FeedGroup
end
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/models/
git commit -m "feat: add Sequel models for Feed, FeedItem, FeedGroup"
```

---

## Task 5: RSpec setup + FactoryBot

**Files:** Create `backend/spec/spec_helper.rb`, `backend/spec/support/factories.rb`, `backend/.rspec`

- [ ] **Step 1: Write `backend/.rspec`**

```
--require spec_helper
--format documentation
--color
```

- [ ] **Step 2: Write `backend/spec/spec_helper.rb`**

```ruby
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
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
    DatabaseCleaner[:sequel, { db: DB }].strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner[:sequel].cleaning { example.run }
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
```

- [ ] **Step 3: Write `backend/spec/support/factories.rb`**

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :feed do
    sequence(:url) { |n| "https://example#{n}.com/feed.xml" }
    title { 'Example Feed' }
    site_url { 'https://example.com' }
    fetch_interval_minutes { 60 }
    created_at { Time.now }
    updated_at { Time.now }
  end

  factory :feed_item do
    association :feed
    sequence(:guid) { |n| "guid-#{n}" }
    title { 'Test Item' }
    url { 'https://example.com/item/1' }
    content_html { '<p>Content</p>' }
    summary { 'Summary text' }
    published_at { Time.now - 3600 }
    fetched_at { Time.now }
    is_read { false }
    is_starred { false }
  end

  factory :feed_group do
    sequence(:name) { |n| "Group #{n}" }
    created_at { Time.now }
    updated_at { Time.now }
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add backend/spec/ backend/.rspec
git commit -m "chore: add RSpec + FactoryBot + DatabaseCleaner setup"
```

---

## Task 6: Sinatra app + route stubs + health endpoint

**Files:** Create `backend/app/app.rb`, `backend/app/routes/feeds.rb`, `backend/app/routes/items.rb`, `backend/app/routes/groups.rb`, `backend/config.ru`

- [ ] **Step 1: Write failing health test `backend/spec/routes/health_spec.rb`**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/app'

RSpec.describe 'Health endpoint' do
  def app = Reader::App

  it 'returns 200 with status ok' do
    get '/health'
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['status']).to eq('ok')
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && bundle exec rspec spec/routes/health_spec.rb
```

Expected: FAIL — `uninitialized constant Reader`

- [ ] **Step 3: Write `backend/app/routes/feeds.rb` (stub)**

```ruby
# frozen_string_literal: true

module Reader
  class App
    get '/feeds' do
      json []
    end

    post '/feeds' do
      status 501
      json error: 'not implemented'
    end

    delete '/feeds/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/feeds/import' do
      status 501
      json error: 'not implemented'
    end

    get '/feeds/export' do
      status 501
      json error: 'not implemented'
    end
  end
end
```

- [ ] **Step 4: Write `backend/app/routes/items.rb` (stub)**

```ruby
# frozen_string_literal: true

module Reader
  class App
    get '/items' do
      json []
    end

    patch '/items/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/items/mark-all-read' do
      status 501
      json error: 'not implemented'
    end
  end
end
```

- [ ] **Step 5: Write `backend/app/routes/groups.rb` (stub)**

```ruby
# frozen_string_literal: true

module Reader
  class App
    get '/groups' do
      json []
    end

    post '/groups' do
      status 501
      json error: 'not implemented'
    end

    delete '/groups/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/groups/:id/feeds' do
      status 501
      json error: 'not implemented'
    end
  end
end
```

- [ ] **Step 6: Write `backend/app/app.rb`**

```ruby
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
```

- [ ] **Step 7: Write `backend/config.ru`**

```ruby
# frozen_string_literal: true

require_relative 'app/app'

use Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'http://localhost:5173')
    resource '*', headers: :any, methods: %i[get post patch delete options]
  end
end

run Reader::App
```

- [ ] **Step 8: Run health test to verify it passes**

```bash
cd backend && bundle exec rspec spec/routes/health_spec.rb
```

Expected: PASS

- [ ] **Step 9: Run full spec suite**

```bash
cd backend && bundle exec rspec
```

Expected: all pass.

- [ ] **Step 10: Commit**

```bash
git add backend/app/ backend/config.ru
git commit -m "feat: Sinatra app skeleton with health endpoint and route stubs"
```

---

## Task 7: Rubocop config

**Files:** Create `backend/.rubocop.yml`

- [ ] **Step 1: Write `backend/.rubocop.yml`**

```yaml
require:
  - rubocop-sequel
  - rubocop-rspec

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3
  Exclude:
    - 'db/migrations/**/*'
    - 'vendor/**/*'

Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: true

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'

RSpec/ExampleLength:
  Max: 20
```

- [ ] **Step 2: Run Rubocop**

```bash
cd backend && bundle exec rubocop --autocorrect-all
```

Expected: auto-corrects minor issues; exits cleanly.

- [ ] **Step 3: Commit**

```bash
git add backend/.rubocop.yml
git commit -m "chore: add Rubocop config"
```

---

## Task 8: Frontend scaffold (Vite + React)

**Files:** Create `frontend/package.json`, `frontend/vite.config.js`, `frontend/index.html`, `frontend/src/main.jsx`, `frontend/src/App.jsx`

- [ ] **Step 1: Scaffold Vite app**

```bash
cd frontend && npm create vite@latest . -- --template react
```

When prompted about non-empty directory: confirm overwrite.

- [ ] **Step 2: Install deps**

```bash
cd frontend && npm install
npm install react-window
```

- [ ] **Step 3: Update `frontend/vite.config.js` to proxy `/api` to backend**

```javascript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:9292',
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
})
```

- [ ] **Step 4: Write minimal `frontend/src/App.jsx`**

```jsx
export default function App() {
  return <div className="app">RSS Reader loading…</div>
}
```

- [ ] **Step 5: Verify dev server starts**

```bash
cd frontend && npm run dev
```

Expected: Vite serves on http://localhost:5173 — browser shows "RSS Reader loading…"

Stop the server (`Ctrl+C`).

- [ ] **Step 6: Commit**

```bash
git add frontend/
git commit -m "chore: scaffold React/Vite frontend"
```

---

## Task 9: Docker

**Files:** Create `backend/Dockerfile`, `frontend/Dockerfile`, `frontend/nginx.conf`, `docker-compose.yml`, `docker-compose.dev.yml`

- [ ] **Step 1: Write `backend/Dockerfile`**

```dockerfile
# Stage 1: build gems
FROM ruby:3.3.4-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential libsqlite3-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development:test \
 && bundle install --jobs 4 --retry 3

# Stage 2: runtime
FROM ruby:3.3.4-slim AS runtime
RUN apt-get update && apt-get install -y libsqlite3-0 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/sh app
WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .
RUN mkdir -p db && chown -R app:app /app
USER app
EXPOSE 9292
CMD ["bundle", "exec", "puma", "-p", "9292", "config.ru"]
```

- [ ] **Step 2: Write `frontend/nginx.conf`**

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://backend:9292/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

- [ ] **Step 3: Write `frontend/Dockerfile`**

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: serve
FROM nginx:alpine AS runtime
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

- [ ] **Step 4: Write `docker-compose.yml`**

```yaml
services:
  backend:
    build: ./backend
    environment:
      DATABASE_URL: sqlite:///data/reader.db
      LOG_LEVEL: ${LOG_LEVEL:-info}
      POLL_INTERVAL_DEFAULT_MINUTES: ${POLL_INTERVAL_DEFAULT_MINUTES:-60}
      MAX_ITEMS_PER_FEED: ${MAX_ITEMS_PER_FEED:-500}
    volumes:
      - db_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9292/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped

  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped

volumes:
  db_data:
```

- [ ] **Step 5: Write `docker-compose.dev.yml`**

```yaml
services:
  backend:
    build:
      context: ./backend
      target: builder
    command: bundle exec rerun -- rackup config.ru -p 9292
    environment:
      DATABASE_URL: sqlite:///data/reader.db
      RACK_ENV: development
      LOG_LEVEL: debug
    volumes:
      - ./backend:/app
      - db_data:/data
    ports:
      - "9292:9292"

  frontend:
    image: node:20-alpine
    working_dir: /app
    command: npm run dev -- --host
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
      - /app/node_modules
```

- [ ] **Step 6: Create `docker-compose.override.yml.example`** (committed; developers copy to `docker-compose.override.yml` locally)

```bash
cp docker-compose.dev.yml docker-compose.override.yml.example
```

Note: `docker-compose.override.yml` is gitignored; the `.example` is committed so developers know how to wire dev mode.

- [ ] **Step 7: Commit**

```bash
git add backend/Dockerfile frontend/Dockerfile frontend/nginx.conf docker-compose.yml docker-compose.dev.yml docker-compose.override.yml.example
git commit -m "chore: add Docker multi-stage builds and compose configs"
```

---

## Task 10: README, LICENSE, and .dockerignore

**Files:** Create `README.md`, `LICENSE`, `backend/.dockerignore`, `frontend/.dockerignore`

- [ ] **Step 1: Write `LICENSE`**

```
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

- [ ] **Step 2: Write `README.md`**

```markdown
# RSS Reader

A personal, desktop-first RSS reader that recreates the Google Reader experience — fast, keyboard-driven, chronological.

> ⚠️ Single-user, no authentication. Do **not** expose to the open internet without adding an auth layer (e.g. nginx basic auth or an SSO proxy) in front.

## Quick start

```bash
cp .env.example .env          # edit SECRET_KEY at minimum
docker compose up
```

Open http://localhost

## Import feeds (OPML)

Via curl:
```bash
curl -X POST http://localhost/api/feeds/import \
  -H 'Content-Type: text/xml' \
  --data-binary @my-feeds.opml
```

Via the UI: not yet implemented — use curl.

## Backup

The database is a single SQLite file inside a named Docker volume (`db_data`). To back it up:

```bash
docker run --rm -v reader_db_data:/data -v $(pwd):/backup alpine \
  cp /data/reader.db /backup/reader-backup.db
```

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `j` | Next item |
| `k` | Previous item |
| `Space` | Page down / advance to next item at bottom |
| `Shift+Space` | Page up |
| `m` | Toggle read/unread |
| `s` | Toggle star |
| `r` | Refresh selected feed |
| `g a` | Go to All Items |
| `?` | Show/hide shortcut overlay |

## Development mode

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

Backend hot-reloads via `rerun`; frontend uses Vite HMR on http://localhost:5173.

Or run without Docker:
```bash
cd backend && bundle exec rake db:migrate && bundle exec rackup config.ru -p 9292
cd frontend && npm run dev
```

## Contributing

1. Fork, create a feature branch, write tests first (RSpec backend, Vitest frontend).
2. `cd backend && bundle exec rspec` — all green.
3. `cd frontend && npm test` — all green.
4. Open a PR.
```

- [ ] **Step 3: Write `backend/.dockerignore`**

```
spec/
tmp/
db/*.db
.bundle/
vendor/
.rubocop.yml
Dockerfile
```

- [ ] **Step 4: Write `frontend/.dockerignore`**

```
node_modules/
dist/
*.test.js
*.test.jsx
Dockerfile
nginx.conf
```

- [ ] **Step 5: Commit**

```bash
git add README.md LICENSE backend/.dockerignore frontend/.dockerignore
git commit -m "chore: add README, MIT licence, and .dockerignore files"
```

---

## Done

Scaffold complete. Verify end state:

```bash
cd backend && bundle exec rspec          # all green
cd backend && bundle exec rubocop        # no offences
cd backend && bundle exec rake db:migrate && bundle exec rake db:migrate_test
docker compose build                     # both images build cleanly
```

Next plan: `2026-04-30-01-feed-management.md`
