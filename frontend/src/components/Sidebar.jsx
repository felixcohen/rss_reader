import React from 'react'
import './Sidebar.css'

export function Sidebar({ feeds, groups, selectedFeedId, onSelect, onSelectAll, onSelectStarred, starredOnly, onAdmin }) {
  const feedById = Object.fromEntries(feeds.map((f) => [f.id, f]))

  const feedsByGroup = {}
  const groupedFeedIds = new Set()
  groups.forEach((group) => {
    feedsByGroup[group.id] = (group.feed_ids || []).map((id) => feedById[id]).filter(Boolean)
    ;(group.feed_ids || []).forEach((id) => groupedFeedIds.add(id))
  })
  const ungrouped = feeds.filter((f) => !groupedFeedIds.has(f.id))

  function FeedButton({ feed }) {
    return (
      <button
        className={`sidebar-item ${selectedFeedId === feed.id ? 'selected' : ''}`}
        onClick={() => onSelect(feed.id)}
      >
        {feed.favicon_url && (
          <img src={feed.favicon_url} alt="" className="favicon" width={16} height={16} />
        )}
        <span className="feed-title">{feed.title || feed.url}</span>
        {feed.unread_count > 0 && (
          <span className="unread-badge">{feed.unread_count}</span>
        )}
      </button>
    )
  }

  return (
    <nav className="sidebar">
      <button
        className={`sidebar-item sidebar-all ${!selectedFeedId && !starredOnly ? 'selected' : ''}`}
        onClick={onSelectAll}
      >
        All Items
      </button>

      {groups.map((group) => (
        <div key={group.id} className="sidebar-group">
          <div className="sidebar-group-label">{group.name}</div>
          {(feedsByGroup[group.id] || []).map((feed) => (
            <FeedButton key={feed.id} feed={feed} />
          ))}
        </div>
      ))}

      <div className="sidebar-feeds">
        {ungrouped.map((feed) => <FeedButton key={feed.id} feed={feed} />)}
      </div>

      <div className="sidebar-divider" />
      <button
        className={`sidebar-item sidebar-starred ${starredOnly ? 'selected' : ''}`}
        onClick={onSelectStarred}
      >
        ★ Starred
      </button>

      <button className="sidebar-admin-btn" onClick={onAdmin} title="Admin">⚙</button>
    </nav>
  )
}
