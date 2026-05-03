import { useState, useRef } from 'react'
import { api } from '../api'
import './AdminPage.css'

export function AdminPage({ feeds, onClose, onFeedsChanged }) {
  return (
    <div className="admin-page">
      <div className="admin-header">
        <button className="admin-back" onClick={onClose}>← Back to reader</button>
        <h1>Admin</h1>
      </div>
      <div className="admin-body">
        <AddFeedSection onFeedsChanged={onFeedsChanged} />
        <OpmlSection onFeedsChanged={onFeedsChanged} />
        <FeedListSection feeds={feeds} onFeedsChanged={onFeedsChanged} />
      </div>
    </div>
  )
}

function AddFeedSection({ onFeedsChanged }) {
  const [url, setUrl]       = useState('')
  const [status, setStatus] = useState(null)
  const [busy, setBusy]     = useState(false)

  async function submit(e) {
    e.preventDefault()
    if (!url.trim()) return
    setBusy(true)
    setStatus(null)
    try {
      const feed = await api.addFeed(url.trim())
      setStatus({ ok: true, message: `Added: ${feed.title || feed.url}` })
      setUrl('')
      onFeedsChanged()
    } catch (err) {
      setStatus({ ok: false, message: err.message })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="admin-section">
      <h2>Add feed</h2>
      <form className="add-feed-form" onSubmit={submit}>
        <input
          type="url"
          placeholder="https://example.com/feed.xml"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          disabled={busy}
        />
        <button type="submit" disabled={busy || !url.trim()}>
          {busy ? 'Adding…' : 'Add'}
        </button>
      </form>
      {status && (
        <p className={`admin-status ${status.ok ? 'ok' : 'err'}`}>{status.message}</p>
      )}
    </section>
  )
}

function OpmlSection({ onFeedsChanged }) {
  const fileRef                       = useRef(null)
  const [importStatus, setImportStatus] = useState(null)
  const [busy, setBusy]               = useState(false)

  async function handleImport(e) {
    const file = e.target.files[0]
    if (!file) return
    setBusy(true)
    setImportStatus(null)
    try {
      const xml = await file.text()
      const result = await api.importOpml(xml)
      setImportStatus({
        ok: true,
        message: `Imported ${result.imported} feed${result.imported !== 1 ? 's' : ''}` +
          (result.errors?.length ? ` (${result.errors.length} failed)` : ''),
      })
      onFeedsChanged()
    } catch (err) {
      setImportStatus({ ok: false, message: err.message })
    } finally {
      setBusy(false)
      fileRef.current.value = ''
    }
  }

  async function handleExport() {
    try {
      await api.exportOpml()
    } catch (err) {
      alert(`Export failed: ${err.message}`)
    }
  }

  return (
    <section className="admin-section">
      <h2>OPML</h2>
      <div className="opml-actions">
        <div>
          <input
            ref={fileRef}
            type="file"
            accept=".opml,application/xml,text/xml"
            style={{ display: 'none' }}
            onChange={handleImport}
            disabled={busy}
          />
          <button onClick={() => fileRef.current.click()} disabled={busy}>
            {busy ? 'Importing…' : 'Import OPML'}
          </button>
          {importStatus && (
            <span className={`admin-status inline ${importStatus.ok ? 'ok' : 'err'}`}>
              {importStatus.message}
            </span>
          )}
        </div>
        <button onClick={handleExport}>Export OPML</button>
      </div>
    </section>
  )
}

function FeedListSection({ feeds, onFeedsChanged }) {
  const [deleting, setDeleting] = useState(null)

  async function deleteFeed(feed) {
    if (!confirm(`Remove "${feed.title || feed.url}"?`)) return
    setDeleting(feed.id)
    try {
      await api.deleteFeed(feed.id)
      onFeedsChanged()
    } finally {
      setDeleting(null)
    }
  }

  return (
    <section className="admin-section">
      <h2>Feeds ({feeds.length})</h2>
      <table className="feed-table">
        <thead>
          <tr>
            <th>Title</th>
            <th>URL</th>
            <th>Unread</th>
            <th>Last fetched</th>
            <th>Error</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {feeds.map((feed) => (
            <tr key={feed.id} className={feed.last_error ? 'feed-row-error' : ''}>
              <td>{feed.title || '—'}</td>
              <td className="feed-url-cell">
                <a href={feed.site_url || feed.url} target="_blank" rel="noopener noreferrer">
                  {feed.url}
                </a>
              </td>
              <td>{feed.unread_count}</td>
              <td>{feed.last_fetched_at ? new Date(feed.last_fetched_at).toLocaleString() : '—'}</td>
              <td className="feed-error-cell">{feed.last_error || ''}</td>
              <td>
                <button
                  className="delete-btn"
                  onClick={() => deleteFeed(feed)}
                  disabled={deleting === feed.id}
                >
                  {deleting === feed.id ? '…' : 'Remove'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
