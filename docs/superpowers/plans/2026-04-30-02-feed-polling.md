# Feed Polling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run a background rufus-scheduler loop that polls all feeds on their individual intervals, upserts new items, fetches favicons on first poll, and exposes per-feed error state and a manual refresh endpoint.

**Architecture:** `FeedPoller` service encapsulates one poll cycle (reuses `FeedFetcher`). `FaviconFetcher` service resolves and stores a favicon URL. rufus-scheduler is started in `config.ru` after the Rack app, firing `FeedPoller.poll_all` on a fixed heartbeat (every minute); each feed decides internally if its own interval has elapsed. Manual refresh at `GET /feeds/:id/refresh` calls `FeedPoller.poll_one` synchronously.

**Tech Stack:** rufus-scheduler, Net::HTTP (favicon), existing FeedFetcher, RSpec + WebMock

**Prerequisite:** Feed management plan complete (FeedFetcher, Feed model, feed routes present).

---

## File Map

```
backend/
  app/
    services/
      feed_poller.rb          # poll_all, poll_one — decides interval, calls FeedFetcher
      favicon_fetcher.rb      # resolve /favicon.ico or <link rel=icon>, persist url
    routes/
      feeds.rb                # add GET /feeds/:id/refresh
  config.ru                   # start rufus-scheduler after app
  spec/
    services/
      feed_poller_spec.rb
      favicon_fetcher_spec.rb
    routes/
      feed_refresh_spec.rb
```

---

## Task 1: FaviconFetcher service

**Files:** Create `backend/app/services/favicon_fetcher.rb`, `backend/spec/services/favicon_fetcher_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/favicon_fetcher'

RSpec.describe FaviconFetcher do
  before do
    stub_request(:head, 'https://example.com/favicon.ico')
      .to_return(status: 200, headers: { 'Content-Type' => 'image/gif' })
    stub_request(:head, 'https://nofavicon.example.com/favicon.ico')
      .to_return(status: 404)
  end

  describe '.call' do
    it 'returns the favicon URL when /favicon.ico exists' do
      url = FaviconFetcher.call('https://example.com')
      expect(url).to eq('https://example.com/favicon.ico')
    end

    it 'returns nil when favicon not found' do
      url = FaviconFetcher.call('https://nofavicon.example.com')
      expect(url).to be_nil
    end

    it 'returns nil on connection error' do
      stub_request(:head, 'https://broken.example.com/favicon.ico').to_timeout
      url = FaviconFetcher.call('https://broken.example.com')
      expect(url).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/services/favicon_fetcher_spec.rb
```

- [ ] **Step 3: Write `backend/app/services/favicon_fetcher.rb`**

```ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'

class FaviconFetcher
  TIMEOUT = 5

  def self.call(site_url)
    new(site_url).call
  end

  def initialize(site_url)
    @site_url = site_url.to_s.chomp('/')
  end

  def call
    favicon_url = "#{@site_url}/favicon.ico"
    uri = URI.parse(favicon_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.head(uri.request_uri)
    response.is_a?(Net::HTTPSuccess) ? favicon_url : nil
  rescue StandardError
    nil
  end
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/services/favicon_fetcher_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/favicon_fetcher.rb backend/spec/services/favicon_fetcher_spec.rb
git commit -m "feat: FaviconFetcher — probe /favicon.ico and return URL"
```

---

## Task 2: FeedPoller service

**Files:** Create `backend/app/services/feed_poller.rb`, `backend/spec/services/feed_poller_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/feed_poller'

RSpec.describe FeedPoller do
  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  before do
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
    stub_request(:head, 'https://example.com/favicon.ico')
      .to_return(status: 200)
    stub_request(:get, 'https://error.example.com/feed.xml')
      .to_return(status: 500)
  end

  describe '.poll_one' do
    let(:feed) { create(:feed, url: 'https://example.com/feed.xml', last_fetched_at: nil) }

    it 'updates last_fetched_at on success' do
      FeedPoller.poll_one(feed)
      expect(feed.refresh.last_fetched_at).not_to be_nil
    end

    it 'clears last_error on success' do
      feed.update(last_error: 'previous error')
      FeedPoller.poll_one(feed)
      expect(feed.refresh.last_error).to be_nil
    end

    it 'sets favicon_url on first successful poll' do
      FeedPoller.poll_one(feed)
      expect(feed.refresh.favicon_url).not_to be_nil
    end

    it 'does not re-fetch favicon when already set' do
      feed.update(favicon_url: 'https://example.com/favicon.ico')
      FeedPoller.poll_one(feed)
      expect(WebMock).not_to have_requested(:head, 'https://example.com/favicon.ico')
    end

    context 'when fetch fails' do
      let(:feed) { create(:feed, url: 'https://error.example.com/feed.xml') }

      it 'records last_error' do
        FeedPoller.poll_one(feed)
        expect(feed.refresh.last_error).to match(/HTTP 500/)
      end
    end
  end

  describe '.poll_all' do
    it 'polls feeds whose interval has elapsed' do
      due = create(:feed, url: 'https://example.com/feed.xml',
                          last_fetched_at: 2.hours.ago,
                          fetch_interval_minutes: 60)
      not_due = create(:feed, url: 'https://error.example.com/feed.xml',
                              last_fetched_at: 10.minutes.ago,
                              fetch_interval_minutes: 60)

      FeedPoller.poll_all
      expect(due.refresh.last_fetched_at).to be > 1.minutes.ago
      expect(not_due.refresh.last_error).to be_nil
    end

    it 'polls feeds never fetched before' do
      feed = create(:feed, url: 'https://example.com/feed.xml', last_fetched_at: nil)
      FeedPoller.poll_all
      expect(feed.refresh.last_fetched_at).not_to be_nil
    end
  end
end
```

Note: Add a simple `Time#ago` helper to spec_helper or use explicit arithmetic (`Time.now - 7200`).

- [ ] **Step 2: Add time helper to `spec/spec_helper.rb`**

After the existing `RSpec.configure` block, add:

```ruby
class Integer
  def hours
    self * 3600
  end

  def minutes
    self * 60
  end

  def ago
    Time.now - self
  end
end
```

- [ ] **Step 3: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/services/feed_poller_spec.rb
```

- [ ] **Step 4: Write `backend/app/services/feed_poller.rb`**

```ruby
# frozen_string_literal: true

require_relative 'feed_fetcher'
require_relative 'favicon_fetcher'

class FeedPoller
  def self.poll_one(feed)
    new(feed).poll
  end

  def self.poll_all
    due_feeds.each { |feed| new(feed).poll }
  end

  def self.due_feeds
    Feed.where(
      Sequel.lit(
        'last_fetched_at IS NULL OR ' \
        'last_fetched_at <= datetime("now", "-" || fetch_interval_minutes || " minutes")'
      )
    ).all
  end

  def initialize(feed)
    @feed = feed
  end

  def poll
    result = FeedFetcher.call(@feed.url)

    if result[:error]
      @feed.update(last_error: result[:error])
    else
      updates = { last_fetched_at: Time.now, last_error: nil }
      if @feed.favicon_url.nil? && @feed.site_url
        updates[:favicon_url] = FaviconFetcher.call(@feed.site_url)
      end
      @feed.update(updates)
    end
  rescue StandardError => e
    @feed.update(last_error: e.message)
  end
end
```

- [ ] **Step 5: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/services/feed_poller_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/feed_poller.rb backend/spec/services/feed_poller_spec.rb
git commit -m "feat: FeedPoller service — interval-aware polling with favicon and error tracking"
```

---

## Task 3: Manual refresh route

**Files:** Add `GET /feeds/:id/refresh` to `backend/app/routes/feeds.rb`, create `backend/spec/routes/feed_refresh_spec.rb`

- [ ] **Step 1: Write failing test**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/app'

RSpec.describe 'Feed refresh route' do
  def app = Reader::App

  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  describe 'GET /feeds/:id/refresh' do
    let(:feed) { create(:feed, url: 'https://example.com/feed.xml') }

    before do
      stub_request(:get, 'https://example.com/feed.xml')
        .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:head, 'https://example.com/favicon.ico').to_return(status: 200)
    end

    it 'polls the feed and returns updated feed JSON' do
      get "/feeds/#{feed.id}/refresh"
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['id']).to eq(feed.id)
      expect(body['last_fetched_at']).not_to be_nil
    end

    it 'returns 404 for unknown feed' do
      get '/feeds/9999/refresh'
      expect(last_response.status).to eq(404)
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/routes/feed_refresh_spec.rb
```

- [ ] **Step 3: Add route to `backend/app/routes/feeds.rb`**

Add `require_relative '../services/feed_poller'` at the **top** of the file alongside the existing requires, then add the route inside `module Reader; class App`:

```ruby
# At top of file, alongside existing requires:
require_relative '../services/feed_fetcher'
require_relative '../services/opml_parser'
require_relative '../services/feed_poller'   # add this line

# Route (inside module Reader; class App):
get '/feeds/:id/refresh' do
  feed = Feed[params[:id].to_i]
  halt 404, json(error: 'Not found') unless feed

  FeedPoller.poll_one(feed)
  json feed.refresh.to_api
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/routes/feed_refresh_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/feeds.rb backend/spec/routes/feed_refresh_spec.rb
git commit -m "feat: GET /feeds/:id/refresh — trigger manual feed poll"
```

---

## Task 4: Wire rufus-scheduler into config.ru

**Files:** Modify `backend/config.ru`

- [ ] **Step 1: Update `backend/config.ru`**

```ruby
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
```

- [ ] **Step 2: Run full test suite to verify nothing broken**

```bash
cd backend && bundle exec rspec
```

Expected: all pass (scheduler not started in test env).

- [ ] **Step 3: Commit**

```bash
git add backend/config.ru
git commit -m "feat: start rufus-scheduler feed poller in config.ru"
```

---

## Done

Verify end state:

```bash
cd backend && bundle exec rspec   # all green
```

Start server and watch logs:
```bash
cd backend && bundle exec rackup config.ru -p 9292
# After 60s, scheduler fires — should see poll activity in logs
```

Next plan: `2026-04-30-03-items-api.md`
