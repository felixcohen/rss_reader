import { useState, useEffect, useCallback } from 'react'
import { api } from '../api'

export function useFeeds() {
  const [feeds, setFeeds] = useState([])
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const load = useCallback(async () => {
    try {
      const [feedData, groupData] = await Promise.all([api.getFeeds(), api.getGroups()])
      setFeeds(feedData)
      setGroups(groupData)
      setLoading(false)
    } catch (e) {
      setError(e)
    }
  }, [])

  useEffect(() => { load() }, [load])

  function adjustUnreadCount(feedId, delta) {
    setFeeds((prev) => prev.map((f) =>
      f.id === feedId ? { ...f, unread_count: delta === -Infinity ? 0 : Math.max(0, (f.unread_count ?? 0) + delta) } : f
    ))
  }

  return { feeds, groups, loading, error, reload: load, adjustUnreadCount }
}
