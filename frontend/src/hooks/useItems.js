import { useState, useEffect, useCallback, useRef } from 'react'
import { api } from '../api'

export function useItems({ feedId, groupId, unreadOnly }) {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(false)
  const [nextBeforeId, setNextBeforeId] = useState(null)
  const prefetchRef = useRef(null)

  const load = useCallback(async (replace = true) => {
    setLoading(true)
    const params = { limit: 50 }
    if (feedId)     params.feed_id    = feedId
    if (groupId)    params.group_id   = groupId
    if (unreadOnly) params.unread_only = true

    const data = await api.getItems(params)
    setItems(replace ? data.items : (prev) => [...prev, ...data.items])
    setNextBeforeId(data.next_before_id)
    setLoading(false)

    if (data.next_before_id) {
      prefetchRef.current = api.getItems({ ...params, before_id: data.next_before_id })
    }
  }, [feedId, groupId, unreadOnly])

  const loadMore = useCallback(async () => {
    if (!nextBeforeId) return
    const prefetched = prefetchRef.current ? await prefetchRef.current : null
    prefetchRef.current = null

    const data = prefetched || await api.getItems({
      limit: 50,
      before_id: nextBeforeId,
      ...(feedId     ? { feed_id:    feedId }    : {}),
      ...(groupId    ? { group_id:   groupId }   : {}),
      ...(unreadOnly ? { unread_only: true }     : {}),
    })
    setItems((prev) => [...prev, ...data.items])
    setNextBeforeId(data.next_before_id)
  }, [nextBeforeId, feedId, groupId, unreadOnly])

  useEffect(() => { load(true) }, [load])

  function updateItem(id, updates) {
    setItems((prev) => prev.map((item) => item.id === id ? { ...item, ...updates } : item))
  }

  return { items, loading, nextBeforeId, loadMore, updateItem, reload: () => load(true) }
}
