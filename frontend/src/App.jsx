import { useState, useCallback } from 'react'
import './App.css'
import { useFeeds }        from './hooks/useFeeds'
import { useItems }        from './hooks/useItems'
import { useReadQueue }    from './hooks/useReadQueue'
import { useKeyboard }     from './hooks/useKeyboard'
import { Sidebar }         from './components/Sidebar'
import { ItemList }        from './components/ItemList'
import { ArticlePane }     from './components/ArticlePane'
import { ShortcutOverlay } from './components/ShortcutOverlay'
import { api }             from './api'

export default function App() {
  const [selectedFeedId, setSelectedFeedId] = useState(null)
  const [selectedItem,   setSelectedItem]   = useState(null)
  const [showHelp,       setShowHelp]       = useState(false)

  const { feeds, groups, reload: reloadFeeds } = useFeeds()
  const { items, loadMore, nextBeforeId, updateItem, reload: reloadItems } = useItems({
    feedId: selectedFeedId,
    groupId: null,
    unreadOnly: false,
  })

  const { enqueue: enqueueRead } = useReadQueue()

  const selectedIndex = items.findIndex((i) => i.id === selectedItem?.id)

  const selectItem = useCallback((item) => {
    setSelectedItem(item)
    if (item && !item.is_read) {
      updateItem(item.id, { is_read: true })
      enqueueRead(item.id)
    }
  }, [updateItem, enqueueRead])

  const handlers = {
    onNext: () => {
      const next = items[selectedIndex + 1]
      if (next) selectItem(next)
    },
    onPrev: () => {
      const prev = items[selectedIndex - 1]
      if (prev) selectItem(prev)
    },
    onToggleRead: async () => {
      if (!selectedItem) return
      const updated = await api.patchItem(selectedItem.id, { is_read: !selectedItem.is_read })
      updateItem(selectedItem.id, { is_read: updated.is_read })
      setSelectedItem((prev) => ({ ...prev, is_read: updated.is_read }))
    },
    onToggleStar: async () => {
      if (!selectedItem) return
      const updated = await api.patchItem(selectedItem.id, { is_starred: !selectedItem.is_starred })
      updateItem(selectedItem.id, { is_starred: updated.is_starred })
      setSelectedItem((prev) => ({ ...prev, is_starred: updated.is_starred }))
    },
    onRefresh: async () => {
      if (!selectedFeedId) return
      await api.refreshFeed(selectedFeedId)
      await reloadFeeds()
      reloadItems()
    },
    onGoAll:  () => { setSelectedFeedId(null); setSelectedItem(null) },
    onHelp:   () => setShowHelp((v) => !v),
    onSpace: () => {
      const pane = document.querySelector('.article-pane')
      if (pane) {
        const remaining = pane.scrollHeight - pane.scrollTop - pane.clientHeight
        if (remaining <= 0) handlers.onNext()
        else pane.scrollBy({ top: pane.clientHeight * 0.9, behavior: 'smooth' })
      }
    },
    onShiftSpace: () => {
      const pane = document.querySelector('.article-pane')
      pane?.scrollBy({ top: -(pane.clientHeight * 0.9), behavior: 'smooth' })
    },
  }

  useKeyboard(handlers)

  return (
    <div className="app">
      <Sidebar
        feeds={feeds}
        groups={groups}
        selectedFeedId={selectedFeedId}
        onSelect={(id) => { setSelectedFeedId(id); setSelectedItem(null) }}
        onSelectAll={() => { setSelectedFeedId(null); setSelectedItem(null) }}
      />
      <ItemList
        items={items}
        feeds={feeds}
        selectedItemId={selectedItem?.id}
        onSelect={selectItem}
        onLoadMore={loadMore}
        hasMore={!!nextBeforeId}
      />
      <ArticlePane item={selectedItem} />
      {showHelp && <ShortcutOverlay onClose={() => setShowHelp(false)} />}
    </div>
  )
}
