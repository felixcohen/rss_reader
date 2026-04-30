import { renderHook, act } from '@testing-library/react'
import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest'
import { useReadQueue } from './useReadQueue'

vi.mock('../api', () => ({
  api: { patchItem: vi.fn().mockResolvedValue({}) },
}))

import { api } from '../api'

describe('useReadQueue', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.clearAllMocks()
  })
  afterEach(() => { vi.useRealTimers() })

  it('batches mark-as-read calls within debounce window', async () => {
    const { result } = renderHook(() => useReadQueue())

    act(() => {
      result.current.enqueue(1)
      result.current.enqueue(2)
    })

    expect(api.patchItem).not.toHaveBeenCalled()

    await act(async () => { vi.advanceTimersByTime(2100) })

    expect(api.patchItem).toHaveBeenCalledTimes(2)
    expect(api.patchItem).toHaveBeenCalledWith(1, { is_read: true })
    expect(api.patchItem).toHaveBeenCalledWith(2, { is_read: true })
  })

  it('does not double-enqueue the same id', async () => {
    const { result } = renderHook(() => useReadQueue())

    act(() => {
      result.current.enqueue(1)
      result.current.enqueue(1)
    })

    await act(async () => { vi.advanceTimersByTime(2100) })

    expect(api.patchItem).toHaveBeenCalledTimes(1)
  })
})
