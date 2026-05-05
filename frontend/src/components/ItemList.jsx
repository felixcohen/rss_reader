import { useCallback, useEffect } from 'react'
import { List, useListRef } from 'react-window'
import { ItemRow } from './ItemRow'
import './ItemList.css'

const ROW_HEIGHT = 72
const EMPTY_ROW_PROPS = {}

export function ItemList({ items, selectedItemId, feeds, onSelect, onLoadMore, hasMore, unreadOnly, onToggleUnreadOnly, unreadCount, style }) {
  const listRef = useListRef()

  const selectedIndex = items.findIndex((i) => i.id === selectedItemId)

  useEffect(() => {
    if (selectedIndex >= 0) {
      listRef.current?.scrollToRow({ index: selectedIndex, align: 'auto' })
    }
  }, [selectedIndex])

  function feedTitle(feedId) {
    return feeds.find((f) => f.id === feedId)?.title ?? ''
  }

  const RowComponent = useCallback(({ index, style }) => {
    if (index === items.length) {
      return hasMore
        ? <div style={style} className="load-more-sentinel" onClick={onLoadMore}>Load more…</div>
        : null
    }

    const item = items[index]
    return (
      <ItemRow
        style={style}
        item={item}
        isSelected={item.id === selectedItemId}
        feedTitle={feedTitle(item.feed_id)}
        onClick={() => onSelect(item)}
      />
    )
  }, [items, selectedItemId, feeds, onSelect, onLoadMore, hasMore])

  return (
    <div className="item-list" style={style}>
      <div className="item-list-toolbar">
        <button
          className={`unread-toggle ${unreadOnly ? 'active' : ''}`}
          onClick={onToggleUnreadOnly}
        >
          Unread only
        </button>
      </div>
      <List
        listRef={listRef}
        rowCount={items.length + (hasMore ? 1 : 0)}
        rowHeight={ROW_HEIGHT}
        rowComponent={RowComponent}
        rowProps={EMPTY_ROW_PROPS}
        style={{ height: 'calc(100% - 36px - 32px)' }}
      />
      <div className="item-list-footer">
        {unreadCount} unread
      </div>
    </div>
  )
}
