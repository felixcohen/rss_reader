import { renderHook, act, waitFor } from '@testing-library/react'
import { vi, describe, it, expect, beforeEach } from 'vitest'
import { useFeeds } from './useFeeds'

const mockFeeds  = [{ id: 1, title: 'Feed A', unread_count: 3 }, { id: 2, title: 'Feed B', unread_count: 0 }]
const mockGroups = [{ id: 1, name: 'Tech', feed_ids: [1] }]

vi.mock('../api', () => ({
  api: {
    getFeeds:  vi.fn(),
    getGroups: vi.fn(),
  },
}))

import { api } from '../api'

beforeEach(() => {
  vi.clearAllMocks()
  api.getFeeds.mockResolvedValue(mockFeeds)
  api.getGroups.mockResolvedValue(mockGroups)
})

describe('useFeeds', () => {
  it('fetches feeds and groups on mount', async () => {
    const { result } = renderHook(() => useFeeds())
    await waitFor(() => expect(result.current.feeds).toEqual(mockFeeds))
    expect(result.current.groups).toEqual(mockGroups)
  })

  it('starts in loading state', () => {
    const { result } = renderHook(() => useFeeds())
    expect(result.current.loading).toBe(true)
  })

  it('clears loading after fetch', async () => {
    const { result } = renderHook(() => useFeeds())
    await waitFor(() => expect(result.current.loading).toBe(false))
  })

  it('sets error state when fetch fails', async () => {
    api.getFeeds.mockRejectedValue(new Error('Network error'))
    const { result } = renderHook(() => useFeeds())
    await waitFor(() => expect(result.current.error).toBeInstanceOf(Error))
  })

  describe('adjustUnreadCount', () => {
    it('decrements unread count for a feed', async () => {
      const { result } = renderHook(() => useFeeds())
      await waitFor(() => expect(result.current.feeds).toEqual(mockFeeds))
      act(() => result.current.adjustUnreadCount(1, -1))
      expect(result.current.feeds.find((f) => f.id === 1).unread_count).toBe(2)
    })

    it('does not go below 0', async () => {
      const { result } = renderHook(() => useFeeds())
      await waitFor(() => expect(result.current.feeds).toEqual(mockFeeds))
      act(() => result.current.adjustUnreadCount(2, -5))
      expect(result.current.feeds.find((f) => f.id === 2).unread_count).toBe(0)
    })

    it('zeroes count when delta is -Infinity', async () => {
      const { result } = renderHook(() => useFeeds())
      await waitFor(() => expect(result.current.feeds).toEqual(mockFeeds))
      act(() => result.current.adjustUnreadCount(1, -Infinity))
      expect(result.current.feeds.find((f) => f.id === 1).unread_count).toBe(0)
    })

    it('increments unread count', async () => {
      const { result } = renderHook(() => useFeeds())
      await waitFor(() => expect(result.current.feeds).toEqual(mockFeeds))
      act(() => result.current.adjustUnreadCount(1, 1))
      expect(result.current.feeds.find((f) => f.id === 1).unread_count).toBe(4)
    })
  })
})
