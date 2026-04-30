# Feed Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all feed CRUD endpoints, OPML bulk import, and group management so feeds can be added, listed (with unread counts), deleted, and organised into folders.

**Architecture:** All logic in `app/services/` — route handlers stay thin (parse params → call service → render JSON). Feed fetching on add uses a `FeedFetcher` service that HTTP-GETs the URL and hands the raw body to Feedjira. OPML import uses `OpmlParser`. Routes live in the existing stub files.

**Tech Stack:** Sinatra 3, Sequel, Feedjira, Nokogiri, Loofah, WebMock (tests), RSpec + Rack::Test, FactoryBot

**Prerequisite:** Scaffolding plan complete (DB migrated, models present, RSpec setup).

---

## File Map

```
backend/
  app/
    services/
      feed_fetcher.rb         # fetch URL → Feedjira parse → persist Feed + initial FeedItems
      opml_parser.rb          # parse OPML XML → array of {title:, url:} hashes
    routes/
      feeds.rb                # replace stubs with real implementations
      groups.rb               # replace stubs with real implementations
  spec/
    services/
      feed_fetcher_spec.rb
      opml_parser_spec.rb
    routes/
      feeds_spec.rb
      groups_spec.rb
    fixtures/
      rss2.xml
      atom.xml
      malformed.xml
      sample.opml
```

---

## Task 1: Fixture feed files

**Files:** Create `spec/fixtures/rss2.xml`, `atom.xml`, `malformed.xml`, `sample.opml`

- [ ] **Step 1: Write `spec/fixtures/rss2.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example RSS Feed</title>
    <link>https://example.com</link>
    <description>Test feed for RSS 2.0</description>
    <item>
      <title>First Post</title>
      <link>https://example.com/1</link>
      <guid>https://example.com/1</guid>
      <description>&lt;p&gt;Hello world&lt;/p&gt;</description>
      <author>alice@example.com</author>
      <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
    </item>
    <item>
      <title>Second Post</title>
      <link>https://example.com/2</link>
      <guid>https://example.com/2</guid>
      <description>&lt;p&gt;Second post&lt;/p&gt;</description>
      <pubDate>Tue, 02 Jan 2024 12:00:00 +0000</pubDate>
    </item>
  </channel>
</rss>
```

- [ ] **Step 2: Write `spec/fixtures/atom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Example Atom Feed</title>
  <link href="https://example.com"/>
  <id>https://example.com/feed</id>
  <updated>2024-01-02T12:00:00Z</updated>
  <entry>
    <title>Atom Entry One</title>
    <link href="https://example.com/atom/1"/>
    <id>https://example.com/atom/1</id>
    <updated>2024-01-01T12:00:00Z</updated>
    <author><name>Bob</name></author>
    <content type="html">&lt;p&gt;Atom content&lt;/p&gt;</content>
  </entry>
</feed>
```

- [ ] **Step 3: Write `spec/fixtures/malformed.xml`**

```xml
<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <title>Malformed Feed</title>
    <!-- missing closing tags and broken entities &amp -->
    <item>
      <title>Broken item
      <guid>broken-guid-1</guid>
    </item>
  </channel>
```

- [ ] **Step 4: Write `spec/fixtures/sample.opml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>My Feeds</title></head>
  <body>
    <outline text="Tech" title="Tech">
      <outline type="rss" text="Example Blog" title="Example Blog"
               xmlUrl="https://example.com/feed.xml"
               htmlUrl="https://example.com"/>
      <outline type="rss" text="Another Blog" title="Another Blog"
               xmlUrl="https://another.com/rss"
               htmlUrl="https://another.com"/>
    </outline>
    <outline type="rss" text="Ungrouped Feed" title="Ungrouped Feed"
             xmlUrl="https://ungrouped.com/feed"
             htmlUrl="https://ungrouped.com"/>
  </body>
</opml>
```

- [ ] **Step 5: Commit**

```bash
git add backend/spec/fixtures/
git commit -m "test: add fixture feed files (RSS2, Atom, malformed, OPML)"
```

---

## Task 2: FeedFetcher service

**Files:** Create `backend/app/services/feed_fetcher.rb`, `backend/spec/services/feed_fetcher_spec.rb`

- [ ] **Step 1: Write failing tests `spec/services/feed_fetcher_spec.rb`**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/services/feed_fetcher'

RSpec.describe FeedFetcher do
  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }
  let(:atom_body) { File.read(File.join(__dir__, '../fixtures/atom.xml')) }
  let(:malformed_body) { File.read(File.join(__dir__, '../fixtures/malformed.xml')) }

  before do
    WebMock.enable!
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
    stub_request(:get, 'https://atom.example.com/feed')
      .to_return(status: 200, body: atom_body, headers: { 'Content-Type' => 'application/atom+xml' })
    stub_request(:get, 'https://malformed.example.com/feed')
      .to_return(status: 200, body: malformed_body, headers: { 'Content-Type' => 'text/xml' })
    stub_request(:get, 'https://notfound.example.com/feed').to_return(status: 404)
    stub_request(:get, 'https://timeout.example.com/feed').to_timeout
  end

  describe '.call' do
    context 'with valid RSS 2.0 feed' do
      it 'creates a Feed record' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed]).to be_a(Feed)
        expect(Feed[url: 'https://example.com/feed.xml']).not_to be_nil
      end

      it 'sets feed title and site_url from parsed feed' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed].title).to eq('Example RSS Feed')
        expect(result[:feed].site_url).to eq('https://example.com')
      end

      it 'creates FeedItem records for each entry' do
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed].feed_items.count).to eq(2)
      end

      it 'sets item fields correctly' do
        FeedFetcher.call('https://example.com/feed.xml')
        item = FeedItem.first(guid: 'https://example.com/1')
        expect(item.title).to eq('First Post')
        expect(item.url).to eq('https://example.com/1')
        expect(item.is_read).to be(false)
      end

      it 'sanitises item content_html' do
        FeedFetcher.call('https://example.com/feed.xml')
        item = FeedItem.first(guid: 'https://example.com/1')
        expect(item.content_html).to include('<p>')
        expect(item.content_html).not_to include('<script')
      end
    end

    context 'with valid Atom feed' do
      it 'creates a Feed and items' do
        result = FeedFetcher.call('https://atom.example.com/feed')
        expect(result[:feed]).to be_a(Feed)
        expect(result[:feed].feed_items.count).to eq(1)
      end
    end

    context 'with HTTP error' do
      it 'returns error hash without persisting' do
        result = FeedFetcher.call('https://notfound.example.com/feed')
        expect(result[:error]).to match(/HTTP 404/)
        expect(Feed.count).to eq(0)
      end
    end

    context 'with network timeout' do
      it 'returns error hash' do
        result = FeedFetcher.call('https://timeout.example.com/feed')
        expect(result[:error]).to be_a(String)
      end
    end

    context 'when feed URL already exists' do
      it 'returns the existing feed without duplication' do
        FeedFetcher.call('https://example.com/feed.xml')
        result = FeedFetcher.call('https://example.com/feed.xml')
        expect(result[:feed]).to be_a(Feed)
        expect(Feed.count).to eq(1)
      end
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/services/feed_fetcher_spec.rb
```

Expected: `uninitialized constant FeedFetcher`

- [ ] **Step 3: Write `backend/app/services/feed_fetcher.rb`**

```ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'feedjira'
require 'loofah'

class FeedFetcher
  TIMEOUT = 15

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    body = fetch_body
    return { error: body } if body.is_a?(String)

    parsed = parse_feed(body)
    return { error: 'Could not parse feed' } if parsed.nil?

    feed = upsert_feed(parsed)
    upsert_items(feed, parsed.entries)
    { feed: feed.refresh }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def fetch_body
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.get(uri.request_uri, 'User-Agent' => 'RSSReader/1.0')
    return "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    "Timeout: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED => e
    "Connection error: #{e.message}"
  end

  def parse_feed(body)
    Feedjira.parse(body)
  rescue StandardError
    nil
  end

  def upsert_feed(parsed)
    existing = Feed[url: @url]
    if existing
      existing.update(last_fetched_at: Time.now, updated_at: Time.now)
      return existing
    end

    Feed.create(
      url: @url,
      title: parsed.title&.strip,
      site_url: parsed.url,
      description: parsed.description&.strip,
      last_fetched_at: Time.now,
      created_at: Time.now,
      updated_at: Time.now
    )
  end

  def upsert_items(feed, entries)
    entries.each do |entry|
      guid = entry.entry_id || entry.url
      next if guid.nil?
      next if FeedItem[:feed_id => feed.id, :guid => guid]

      content = sanitise(entry.content || entry.summary)
      FeedItem.create(
        feed_id: feed.id,
        guid: guid,
        title: entry.title&.strip,
        url: entry.url,
        content_html: content,
        summary: Loofah.fragment(entry.summary.to_s).to_text.strip[0, 500],
        author: entry.author&.strip,
        published_at: entry.published || Time.now,
        fetched_at: Time.now,
        is_read: false,
        is_starred: false
      )
    rescue StandardError
      next
    end
  end

  def sanitise(html)
    return '' if html.nil? || html.empty?

    Loofah.fragment(html)
          .scrub!(:strip)
          .to_s
  end
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/services/feed_fetcher_spec.rb
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/feed_fetcher.rb backend/spec/services/feed_fetcher_spec.rb
git commit -m "feat: FeedFetcher service — fetch, parse, persist feed and items"
```

---

## Task 3: OpmlParser service

**Files:** Create `backend/app/services/opml_parser.rb`, `backend/spec/services/opml_parser_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/services/opml_parser'

RSpec.describe OpmlParser do
  let(:opml_body) { File.read(File.join(__dir__, '../fixtures/sample.opml')) }

  describe '.call' do
    it 'returns array of feed hashes' do
      result = OpmlParser.call(opml_body)
      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end

    it 'extracts xmlUrl and title' do
      result = OpmlParser.call(opml_body)
      urls = result.map { _1[:url] }
      expect(urls).to include('https://example.com/feed.xml')
      expect(urls).to include('https://another.com/rss')
      expect(urls).to include('https://ungrouped.com/feed')
    end

    it 'includes group name for grouped feeds' do
      result = OpmlParser.call(opml_body)
      tech_feeds = result.select { _1[:group] == 'Tech' }
      expect(tech_feeds.length).to eq(2)
    end

    it 'returns nil group for ungrouped feeds' do
      result = OpmlParser.call(opml_body)
      ungrouped = result.find { _1[:url] == 'https://ungrouped.com/feed' }
      expect(ungrouped[:group]).to be_nil
    end

    it 'returns empty array for invalid XML' do
      result = OpmlParser.call('not xml at all')
      expect(result).to eq([])
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/services/opml_parser_spec.rb
```

- [ ] **Step 3: Write `backend/app/services/opml_parser.rb`**

```ruby
# frozen_string_literal: true

require 'nokogiri'

class OpmlParser
  def self.call(xml_body)
    new(xml_body).call
  end

  def initialize(xml_body)
    @xml_body = xml_body
  end

  def call
    doc = Nokogiri::XML(@xml_body) { |c| c.strict }
    return [] if doc.errors.any?

    feeds = []
    doc.css('body > outline').each do |node|
      if node['xmlUrl']
        feeds << build_entry(node, nil)
      else
        group_name = node['title'] || node['text']
        node.css('outline[xmlUrl]').each do |child|
          feeds << build_entry(child, group_name)
        end
      end
    end
    feeds
  rescue Nokogiri::XML::SyntaxError
    []
  end

  private

  def build_entry(node, group)
    {
      url: node['xmlUrl'],
      title: node['title'] || node['text'],
      site_url: node['htmlUrl'],
      group: group
    }
  end
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/services/opml_parser_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/opml_parser.rb backend/spec/services/opml_parser_spec.rb
git commit -m "feat: OpmlParser service — parse OPML to feed array with group names"
```

---

## Task 4: Feed routes

**Files:** Rewrite `backend/app/routes/feeds.rb`, create `backend/spec/routes/feeds_spec.rb`

- [ ] **Step 1: Write failing tests `spec/routes/feeds_spec.rb`**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../app/app'

RSpec.describe 'Feeds routes' do
  def app = Reader::App

  let(:rss_body) { File.read(File.join(__dir__, '../fixtures/rss2.xml')) }

  before do
    stub_request(:get, 'https://example.com/feed.xml')
      .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
  end

  describe 'GET /feeds' do
    it 'returns empty array when no feeds' do
      get '/feeds'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'returns feeds with unread_count' do
      create(:feed, url: 'https://example.com/feed.xml', title: 'Test')
      get '/feeds'
      body = JSON.parse(last_response.body)
      expect(body.length).to eq(1)
      expect(body.first).to include('id', 'url', 'title', 'unread_count')
    end
  end

  describe 'POST /feeds' do
    it 'fetches and returns the new feed' do
      post '/feeds', JSON.generate(url: 'https://example.com/feed.xml'),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body['url']).to eq('https://example.com/feed.xml')
      expect(body['title']).to eq('Example RSS Feed')
    end

    it 'returns 422 when url missing' do
      post '/feeds', JSON.generate({}), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end

    it 'returns 422 for HTTP error response from feed URL' do
      stub_request(:get, 'https://bad.example.com/feed').to_return(status: 404)
      post '/feeds', JSON.generate(url: 'https://bad.example.com/feed'),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end
  end

  describe 'DELETE /feeds/:id' do
    it 'deletes existing feed and returns 204' do
      feed = create(:feed)
      delete "/feeds/#{feed.id}"
      expect(last_response.status).to eq(204)
      expect(Feed[feed.id]).to be_nil
    end

    it 'returns 404 for unknown feed' do
      delete '/feeds/9999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /feeds/import' do
    let(:opml_body) { File.read(File.join(__dir__, '../fixtures/sample.opml')) }

    before do
      stub_request(:get, 'https://example.com/feed.xml')
        .to_return(status: 200, body: rss_body, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, 'https://another.com/rss').to_return(status: 200, body: rss_body)
      stub_request(:get, 'https://ungrouped.com/feed').to_return(status: 200, body: rss_body)
    end

    it 'imports feeds from OPML and returns count' do
      post '/feeds/import', opml_body, 'CONTENT_TYPE' => 'text/xml'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['imported']).to be > 0
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/routes/feeds_spec.rb
```

- [ ] **Step 3: Rewrite `backend/app/routes/feeds.rb`**

```ruby
# frozen_string_literal: true

require_relative '../services/feed_fetcher'
require_relative '../services/opml_parser'

module Reader
  class App
    get '/feeds' do
      feeds = Feed.all.map(&:to_api)
      json feeds
    end

    post '/feeds' do
      params = JSON.parse(request.body.read)
      url = params['url']&.strip
      halt 422, json(error: 'url is required') if url.nil? || url.empty?

      result = FeedFetcher.call(url)
      if result[:error]
        halt 422, json(error: result[:error])
      else
        status 201
        json result[:feed].to_api
      end
    end

    delete '/feeds/:id' do
      feed = Feed[params[:id].to_i]
      halt 404, json(error: 'Not found') unless feed

      feed.destroy
      status 204
    end

    get '/feeds/export' do
      status 501
      json error: 'not implemented'
    end

    post '/feeds/import' do
      body = request.body.read
      entries = OpmlParser.call(body)
      halt 422, json(error: 'Invalid or empty OPML') if entries.empty?

      imported = 0
      errors = []

      entries.each do |entry|
        result = FeedFetcher.call(entry[:url])
        if result[:error]
          errors << { url: entry[:url], error: result[:error] }
        else
          imported += 1
          if entry[:group]
            group = FeedGroup.find_or_create(name: entry[:group]) { |g| g.created_at = Time.now; g.updated_at = Time.now }
            FeedGroupMembership.find_or_create(feed_id: result[:feed].id, group_id: group.id)
          end
        end
      end

      json imported: imported, errors: errors
    end
  end
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/routes/feeds_spec.rb
```

- [ ] **Step 5: Run full suite**

```bash
cd backend && bundle exec rspec
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/feeds.rb backend/spec/routes/feeds_spec.rb
git commit -m "feat: feed management routes — CRUD, OPML import"
```

---

## Task 5: Group routes

**Files:** Rewrite `backend/app/routes/groups.rb`, create `backend/spec/routes/groups_spec.rb`

- [ ] **Step 1: Write failing tests `spec/routes/groups_spec.rb`**

```ruby
# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/app'

RSpec.describe 'Groups routes' do
  def app = Reader::App

  describe 'GET /groups' do
    it 'returns empty array' do
      get '/groups'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end
  end

  describe 'POST /groups' do
    it 'creates a group' do
      post '/groups', JSON.generate(name: 'Tech'), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body['name']).to eq('Tech')
    end

    it 'returns 422 when name missing' do
      post '/groups', JSON.generate({}), 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
    end
  end

  describe 'DELETE /groups/:id' do
    it 'deletes group and returns 204' do
      group = create(:feed_group)
      delete "/groups/#{group.id}"
      expect(last_response.status).to eq(204)
    end

    it 'returns 404 for unknown group' do
      delete '/groups/9999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /groups/:id/feeds' do
    it 'adds feed to group' do
      group = create(:feed_group)
      feed = create(:feed)
      post "/groups/#{group.id}/feeds", JSON.generate(feed_id: feed.id),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(FeedGroupMembership[feed_id: feed.id, group_id: group.id]).not_to be_nil
    end
  end
end
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd backend && bundle exec rspec spec/routes/groups_spec.rb
```

- [ ] **Step 3: Rewrite `backend/app/routes/groups.rb`**

```ruby
# frozen_string_literal: true

module Reader
  class App
    get '/groups' do
      json FeedGroup.all.map(&:to_api)
    end

    post '/groups' do
      params = JSON.parse(request.body.read)
      name = params['name']&.strip
      halt 422, json(error: 'name is required') if name.nil? || name.empty?

      group = FeedGroup.create(name: name, created_at: Time.now, updated_at: Time.now)
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

      body = JSON.parse(request.body.read)
      feed = Feed[body['feed_id'].to_i]
      halt 404, json(error: 'Feed not found') unless feed

      FeedGroupMembership.find_or_create(feed_id: feed.id, group_id: group.id)
      json group.to_api
    end
  end
end
```

- [ ] **Step 4: Run tests to verify PASS**

```bash
cd backend && bundle exec rspec spec/routes/groups_spec.rb
```

- [ ] **Step 5: Run full suite**

```bash
cd backend && bundle exec rspec
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/groups.rb backend/spec/routes/groups_spec.rb
git commit -m "feat: group management routes — CRUD + add feed to group"
```

---

## Done

Feed management complete. Verify:

```bash
cd backend && bundle exec rspec   # all green
```

Manual smoke test (with backend running):
```bash
curl -X POST http://localhost:9292/feeds \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://feeds.feedburner.com/oreilly/radar/atom"}'
curl http://localhost:9292/feeds
```

Next plan: `2026-04-30-02-feed-polling.md`
