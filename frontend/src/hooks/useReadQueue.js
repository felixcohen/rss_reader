import { useRef, useCallback } from 'react'
import { api } from '../api'

const DEBOUNCE_MS = 2000

export function useReadQueue() {
  const queueRef = useRef(new Set())
  const timerRef = useRef(null)

  const flush = useCallback(async () => {
    const ids = Array.from(queueRef.current)
    queueRef.current = new Set()
    await Promise.all(ids.map((id) => api.patchItem(id, { is_read: true })))
  }, [])

  const enqueue = useCallback((id) => {
    queueRef.current.add(id)
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(flush, DEBOUNCE_MS)
  }, [flush])

  return { enqueue }
}
