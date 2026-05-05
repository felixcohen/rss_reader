# RSS Reader

A personal, desktop-first RSS reader that recreates the Google Reader experience — fast, keyboard-driven, chronological.

> ⚠️ Single-user, no authentication. Do **not** expose to the open internet without adding an auth layer (e.g. nginx basic auth or an SSO proxy) in front.

## Quick start

```bash
cp .env.example .env          # edit SECRET_KEY at minimum
docker compose up
```

Open http://localhost:8080

## Import feeds (OPML)

Via curl:
```bash
curl -X POST http://localhost:8080/api/feeds/import \
  -H 'Content-Type: text/xml' \
  --data-binary @my-feeds.opml
```

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
| `v` | Open item URL in new tab |
| `a` | Mark all read (with confirmation) |
| `r` | Refresh selected feed |
| `g a` | Go to All Items |
| `?` / `h` | Show/hide shortcut overlay |

## Development mode

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

Or without Docker:
```bash
cd backend && bundle exec rake db:migrate && bundle exec rackup config.ru -p 9292
cd frontend && npm run dev
```

## Contributing

1. Fork, create a feature branch, write tests first (RSpec backend, Vitest frontend).
2. `cd backend && bundle exec rspec` — all green.
3. `cd frontend && npm test` — all green.
4. Open a PR.
