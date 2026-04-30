import { useRef, useCallback } from 'react'
import { List, useListRef } from 'react-window'
import { ItemRow } from './ItemRow'
import './ItemList.css'

const ROW_HEIGHT = 72
const EMPTY_ROW_PROPS = {}

export function ItemList({ items, selectedItemId, feeds, onSelect, onLoadMore, hasMore }) {
  const listRef = useListRef()

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
    <div className="item-list">
      <List
        listRef={listRef}
        rowCount={items.length + (hasMore ? 1 : 0)}
        rowHeight={ROW_HEIGHT}
        rowComponent={RowComponent}
        rowProps={EMPTY_ROW_PROPS}
        style={{ height: '100%' }}
      />
    </div>
  )
}
