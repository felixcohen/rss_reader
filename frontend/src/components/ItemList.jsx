import { useRef, useCallback } from 'react'
import { FixedSizeList as List } from 'react-window'
import { ItemRow } from './ItemRow'
import './ItemList.css'

const ROW_HEIGHT = 72

export function ItemList({ items, selectedItemId, feeds, onSelect, onLoadMore, hasMore }) {
  const listRef = useRef(null)

  function feedTitle(feedId) {
    return feeds.find((f) => f.id === feedId)?.title ?? ''
  }

  const Row = useCallback(({ index, style }) => {
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
        ref={listRef}
        height={window.innerHeight}
        itemCount={items.length + (hasMore ? 1 : 0)}
        itemSize={ROW_HEIGHT}
        width="100%"
      >
        {Row}
      </List>
    </div>
  )
}
