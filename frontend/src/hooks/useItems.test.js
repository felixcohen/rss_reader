import { renderHook, act, waitFor } from '@testing-library/react'
import { vi, describe, it, expect, beforeEach } from 'vitest'
import { useItems } from './useItems'

vi.mock('../api', () => ({
  api: { getItems: vi.fn() },
}))

import { api } from '../api'

const makePage = (items, next = null) => ({ items, next_before_id: next })
const item  = (id) => ({ id, feed_id: 1, title: `Item ${id}`, is_read: false, is_starred: false })

beforeEach(() => {
  vi.clearAllMocks()
  api.getItems.mockResolvedValue(makePage([item(1), item(2)]))
})

describe('useItems', () => {
  it('fetches items on mount', async () => {
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.items).toHaveLength(2))
  })

  it('sets error when fetch fails', async () => {
    api.getItems.mockRejectedValue(new Error('fail'))
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.error).toBeInstanceOf(Error))
  })

  it('passes feed_id param', async () => {
    renderHook(() => useItems({ feedId: 5 }))
    await waitFor(() => expect(api.getItems).toHaveBeenCalledWith(expect.objectContaining({ feed_id: 5 })))
  })

  it('passes unread_only param', async () => {
    renderHook(() => useItems({ unreadOnly: true }))
    await waitFor(() => expect(api.getItems).toHaveBeenCalledWith(expect.objectContaining({ unread_only: true })))
  })

  it('passes starred_only param', async () => {
    renderHook(() => useItems({ starredOnly: true }))
    await waitFor(() => expect(api.getItems).toHaveBeenCalledWith(expect.objectContaining({ starred_only: true })))
  })

  it('exposes nextBeforeId when more pages exist', async () => {
    api.getItems.mockResolvedValue(makePage([item(1)], 99))
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.nextBeforeId).toBe(99))
  })

  it('appends items on loadMore', async () => {
    api.getItems
      .mockResolvedValueOnce(makePage([item(1), item(2)], 2))
      .mockResolvedValue(makePage([item(3)]))
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.items).toHaveLength(2))
    await act(() => result.current.loadMore())
    expect(result.current.items).toHaveLength(3)
  })

  it('updateItem patches a single item in state', async () => {
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.items).toHaveLength(2))
    act(() => result.current.updateItem(1, { is_read: true }))
    expect(result.current.items.find((i) => i.id === 1).is_read).toBe(true)
    expect(result.current.items.find((i) => i.id === 2).is_read).toBe(false)
  })

  it('reloads items on reload()', async () => {
    const { result } = renderHook(() => useItems({}))
    await waitFor(() => expect(result.current.items).toHaveLength(2))
    api.getItems.mockResolvedValue(makePage([item(1)]))
    await act(() => result.current.reload())
    expect(result.current.items).toHaveLength(1)
  })
})
