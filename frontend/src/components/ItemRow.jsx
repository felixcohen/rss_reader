import React, { memo } from 'react'

export const ItemRow = memo(function ItemRow({ item, isSelected, feedTitle, style, onClick }) {
  const date = item.published_at
    ? new Date(item.published_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
    : ''

  return (
    <div
      style={style}
      className={`item-row ${isSelected ? 'selected' : ''} ${item.is_read ? 'read' : 'unread'}`}
      onClick={onClick}
    >
      <div className="item-row-title">{item.title || '(no title)'}</div>
      <div className="item-row-meta">
        <span className="item-feed">{feedTitle}</span>
        <span className="item-date">{date}</span>
      </div>
      {item.summary && (
        <div className="item-snippet">{item.summary.slice(0, 120)}</div>
      )}
    </div>
  )
})
