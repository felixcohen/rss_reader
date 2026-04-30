# Google Reader Rebuild — Personal RSS Reader

## Project overview
A personal, desktop-first RSS reader that recreates the core Google Reader experience: fast, keyboard-driven, chronological, no algorithmic interference.

## Stack
- **Backend**: Ruby, Sinatra, Sequel ORM with sequel_migrations
- **Background polling**: rufus-scheduler embedded in the Sinatra process
- **Feed parsing**: feedjira + nokogiri; sanitise content with loofah

## Backend conventions
- Ruby 3.3, managed via .ruby-version
- Bundler for dependencies, Gemfile.lock committed
- Rubocop for linting (rubocop-sequel plugin)
- Sinatra modular style (class-based, not top-level DSL)
- Sequel models in app/models/, routes in app/routes/ (one file per resource)
- Rack::Test for API endpoint tests — no Rails test helpers
- RSpec throughout; FactoryBot for fixtures

## Testing approach
- RSpec + Rack::Test for API endpoints
- Fixture feed files (RSS 2.0, Atom, malformed) in spec/fixtures/
- Test the feedjira parse + upsert logic in isolation
- Frontend testing unchanged (React Testing Library)

- **Frontend**: React (Vite), no CSS framework — write plain CSS, desktop layout only
- **Persistence**: SQLite single-file database

## Architecture decisions (do not relitigate)
- SQLite is the database; no MySQL/Postgres
- rufus-scheduler runs embedded in the Sinatra process for feed polling
- No Redis, no Celery
- Feed polling interval: configurable per-feed, default 60 minutes
- No read recommendation, trending, or algorithmic features of any kind

## Data model
Design and implement these entities. Use sequel_migrations from the start.

**Feed**: id, url, title, site_url, description, favicon_url, last_fetched_at, fetch_interval_minutes, created_at  
**FeedItem**: id, feed_id (FK), guid, title, url, content_html, summary, author, published_at, fetched_at, is_read, is_starred  
**FeedGroup** (folders): id, name, created_at  
**FeedGroupMembership**: feed_id, group_id

Index: `(feed_id, published_at DESC)` and `(is_read, published_at DESC)` on FeedItem — these are the hot paths.

## Core features to implement (in this order, each on its own feature branch)

### Branch: feat/feed-management
- POST /feeds — add feed by URL (fetch and parse on add, return feed metadata)
- DELETE /feeds/{id}
- GET /feeds — list all feeds with unread counts
- POST /feeds/import — accept OPML file, bulk import
- POST /groups, DELETE /groups/{id}, POST /groups/{id}/feeds

### Branch: feat/feed-polling  
- Background rufus-scheduler job: poll all feeds on their fetch_interval, parse via feedjira, upsert items by guid
- Fetch favicon on first poll
- Expose GET /feeds/{id}/refresh to trigger manual refresh
- Log polling errors per feed; expose last_error on the feed object

### Branch: feat/items-api
- GET /items?feed_id=&group_id=&unread_only=&limit=&before_id= — paginated, chronological DESC
- GET /items/all — all feeds combined, same pagination
- PATCH /items/{id} — mark read/unread, star/unstar
- POST /items/mark-all-read?feed_id=&group_id= — bulk mark read

### Branch: feat/reader-ui
Implement the full reading UI in React. This is the core product.

**Layout (desktop only, min-width 1024px)**:
- Left sidebar: feed list grouped by folder, unread counts, "All Items" at top
- Middle panel: item list for selected feed/view — title, feed name, date, first line of summary
- Right panel: article content rendered from content_html

**Keyboard shortcuts (global, no modifier needed)**:
- `j` — next item (advances item selection; auto-marks previous as read)
- `k` — previous item  
- `Space` — page down in article panel; if at bottom, advance to next item
- `Shift+Space` — page up
- `r` — refresh selected feed
- `m` — toggle read/unread on selected item
- `s` — toggle star on selected item
- `g a` — go to All Items
- `?` — show keyboard shortcut overlay

**Performance requirements**:
- Item list must use virtual scrolling (react-window or similar) — feeds can have thousands of items
- On feed selection, fetch first page of items immediately; prefetch next page in background
- Mark-as-read writes should be batched (debounce 2s) and optimistic in the UI

**No mobile layout needed. No responsive breakpoints.**

### Branch: feat/opml-export
- GET /feeds/export — return valid OPML of all feeds and groups

## Testing approach (TDD throughout)
- Write RSpec tests before implementing each API endpoint
- Test the feed parser/upsert logic with fixture XML files (provide at least one valid RSS 2.0, one Atom, one malformed feed)
- Frontend: React Testing Library for keyboard navigation logic — test that j/k/space advance state correctly without needing a real API
- Aim for 80%+ coverage on backend business logic; don't chase coverage on glue code

## What good looks like
The reader feels instant. Switching feeds, advancing items, marking read — all sub-100ms perceived. The keyboard shortcuts work without focus being in a particular element. Articles render cleanly with images intact and no feed chrome leaking through. The item list handles 5,000 items without jank.

## Project setup & Docker (first-class, not afterthought)

### Repository structure
monorepo root
├── backend/
├── frontend/
├── docker-compose.yml
├── docker-compose.override.yml.example  (local dev overrides — not committed)
├── .env.example                          (committed; .env is gitignored)
└── README.md

### Docker requirements

**backend/Dockerfile** — multi-stage:
- Stage 1 (builder): install Ruby gems via Bundler
- Stage 2 (runtime): copy bundle only, run as non-root user
- No dev dependencies in the runtime image

**frontend/Dockerfile** — multi-stage:
- Stage 1 (builder): node:20-alpine, npm ci, npm run build
- Stage 2 (runtime): nginx:alpine, serve the Vite build
- Include a default nginx.conf that proxies /api/* to the backend container

**docker-compose.yml** (production-style, works out of the box):
- Services: backend, frontend
- SQLite db file persisted via a named volume mounted at /data/reader.db
- Backend reads DATABASE_URL from environment, defaults to /data/reader.db
- Frontend nginx proxies /api to backend — no CORS config needed
- Health checks on both services
- restart: unless-stopped

**docker-compose.dev.yml** (developer experience):
- Backend: mount source as volume, run with rerun for auto-reload
- Frontend: run Vite dev server (npm run dev) instead of nginx, with HMR
- Override command: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up`

### Environment config
.env.example should document every variable with a comment:
- SECRET_KEY (generate a default random one on first run if not set)
- POLL_INTERVAL_DEFAULT_MINUTES (default: 60)
- MAX_ITEMS_PER_FEED (default: 500 — cap what gets stored to keep db lean)
- LOG_LEVEL (default: info)

### GitHub-readiness
- .gitignore: .env, *.db, *.sqlite, node_modules, dist, .bundle, tmp/
- .dockerignore in both backend/ and frontend/ — exclude tests, docs, .git
- LICENSE file: MIT
- README must include:
  - One-command start: `docker compose up` (and what URL to open)
  - How to import an OPML file (curl command + UI path)
  - How to back up (just copy the named volume's db file — explain this plainly)
  - Keyboard shortcut reference table
  - How to contribute / run in dev mode
  - A note that this is single-user, no auth — do not expose to the open internet without adding auth in front