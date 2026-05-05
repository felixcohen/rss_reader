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
import { AdminPage }       from './components/AdminPage'
import { Modal }           from './components/Modal'
import { api }             from './api'

const SIDEBAR_WIDTH = 240 // must match .sidebar { width } in Sidebar.css

function DragHandle({ onMouseDown }) {
  return <div className="drag-handle" onMouseDown={onMouseDown} />
}

export default function App() {
  const [selectedFeedId,  setSelectedFeedId]  = useState(null)
  const [selectedItem,    setSelectedItem]    = useState(null)
  const [showHelp,        setShowHelp]        = useState(false)
  const [unreadOnly,      setUnreadOnly]      = useState(false)
  const [showAdmin,       setShowAdmin]       = useState(false)
  const [showMarkAllRead, setShowMarkAllRead] = useState(false)
  const [starredOnly,     setStarredOnly]     = useState(false)
  const [itemListWidth,   setItemListWidth]   = useState(360)

  const startDrag = useCallback(function startDrag(e) {
    document.body.style.userSelect = 'none'
    const pane = document.querySelector('.article-pane')
    if (pane) pane.style.pointerEvents = 'none'

    function onMove(e) {
      setItemListWidth(Math.max(200, Math.min(600, e.clientX - SIDEBAR_WIDTH)))
    }
    function onUp() {
      document.body.style.userSelect = ''
      const pane = document.querySelector('.article-pane')
      if (pane) pane.style.pointerEvents = ''
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
  }, [])

  const { feeds, groups, error: feedsError, reload: reloadFeeds, adjustUnreadCount } = useFeeds()
  const { items, loadMore, nextBeforeId, error: itemsError, updateItem, reload: reloadItems } = useItems({
    feedId: starredOnly ? null : selectedFeedId,
    groupId: null,
    unreadOnly: starredOnly ? false : unreadOnly,
    starredOnly,
  })

  const { enqueue: enqueueRead } = useReadQueue()

  const selectedIndex = items.findIndex((i) => i.id === selectedItem?.id)

  const selectItem = useCallback((item) => {
    setSelectedItem(item)
    if (item && !item.is_read) {
      updateItem(item.id, { is_read: true })
      enqueueRead(item.id)
      adjustUnreadCount(item.feed_id, -1)
    }
  }, [updateItem, enqueueRead, adjustUnreadCount])

  async function confirmMarkAllRead() {
    const params = selectedFeedId ? { feed_id: selectedFeedId } : {}
    await api.markAllRead(params)
    if (selectedFeedId) {
      adjustUnreadCount(selectedFeedId, -Infinity)
    } else {
      feeds.forEach((f) => adjustUnreadCount(f.id, -Infinity))
    }
    setSelectedItem(null)
    reloadItems()
    setShowMarkAllRead(false)
  }

  const handlers = {
    onNext: () => {
      const next = items[selectedIndex + 1]
      if (next) selectItem(next)
    },
    onPrev: () => {
      const prev = items[selectedIndex - 1]
      if (prev) selectItem(prev)
    },
    onMarkAllRead: () => setShowMarkAllRead(true),
    onToggleRead: async () => {
      if (!selectedItem) return
      const updated = await api.patchItem(selectedItem.id, { is_read: !selectedItem.is_read })
      updateItem(selectedItem.id, { is_read: updated.is_read })
      setSelectedItem((prev) => ({ ...prev, is_read: updated.is_read }))
      adjustUnreadCount(selectedItem.feed_id, updated.is_read ? -1 : 1)
    },
    onToggleStar: async () => {
      if (!selectedItem) return
      const updated = await api.patchItem(selectedItem.id, { is_starred: !selectedItem.is_starred })
      updateItem(selectedItem.id, { is_starred: updated.is_starred })
      setSelectedItem((prev) => ({ ...prev, is_starred: updated.is_starred }))
    },
    onOpen: () => {
      if (selectedItem?.url) window.open(selectedItem.url, '_blank', 'noopener')
    },
    onRefresh: async () => {
      if (!selectedFeedId) return
      await api.refreshFeed(selectedFeedId)
      await reloadFeeds()
      reloadItems()
    },
    onGoAll:  () => { setSelectedFeedId(null); setSelectedItem(null); setStarredOnly(false) },
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

  const backendError = feedsError || itemsError

  if (showAdmin) {
    return (
      <AdminPage
        feeds={feeds}
        onClose={() => setShowAdmin(false)}
        onFeedsChanged={reloadFeeds}
      />
    )
  }

  const selectedFeedTitle = feeds.find((f) => f.id === selectedFeedId)?.title

  return (
    <div className="app">
      <Sidebar
        feeds={feeds}
        groups={groups}
        selectedFeedId={selectedFeedId}
        onSelect={(id) => { setSelectedFeedId(id); setSelectedItem(null); setStarredOnly(false) }}
        onSelectAll={() => { setSelectedFeedId(null); setSelectedItem(null); setStarredOnly(false) }}
        onSelectStarred={() => { setSelectedFeedId(null); setSelectedItem(null); setStarredOnly(true) }}
        starredOnly={starredOnly}
        onAdmin={() => setShowAdmin(true)}
      />
      <ItemList
        items={items}
        feeds={feeds}
        selectedItemId={selectedItem?.id}
        onSelect={selectItem}
        onLoadMore={loadMore}
        hasMore={!!nextBeforeId}
        unreadOnly={unreadOnly}
        onToggleUnreadOnly={() => setUnreadOnly((v) => !v)}
        unreadCount={selectedFeedId
          ? (feeds.find((f) => f.id === selectedFeedId)?.unread_count ?? 0)
          : feeds.reduce((sum, f) => sum + (f.unread_count ?? 0), 0)}
        style={{ width: itemListWidth }}
      />
      <DragHandle onMouseDown={startDrag} />
      <ArticlePane item={selectedItem} />

      {showHelp && <ShortcutOverlay onClose={() => setShowHelp(false)} />}

      {showMarkAllRead && (
        <Modal
          title="Mark all as read?"
          message={selectedFeedTitle
            ? `This will mark every item in "${selectedFeedTitle}" as read.`
            : 'This will mark every item across all feeds as read.'}
          actions={[
            { label: 'Cancel',       variant: '',        onClick: () => setShowMarkAllRead(false) },
            { label: 'Mark all read', variant: 'primary', onClick: confirmMarkAllRead },
          ]}
          onClose={() => setShowMarkAllRead(false)}
        />
      )}

      {backendError && (
        <Modal
          title="Unable to reach the server"
          message="The app lost connection to the backend. Please restart the app and try again."
          actions={[
            { label: 'Restart app', variant: 'primary', onClick: () => window.location.reload() },
          ]}
        />
      )}
    </div>
  )
}
