import { renderHook, act } from '@testing-library/react'
import { vi, describe, it, expect, beforeEach } from 'vitest'
import { useKeyboard } from './useKeyboard'

function fireKey(key) {
  document.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }))
}

describe('useKeyboard', () => {
  let handlers

  beforeEach(() => {
    handlers = {
      onNext:       vi.fn(),
      onPrev:       vi.fn(),
      onToggleRead: vi.fn(),
      onToggleStar: vi.fn(),
      onRefresh:    vi.fn(),
      onGoAll:      vi.fn(),
      onHelp:       vi.fn(),
      onSpace:      vi.fn(),
      onShiftSpace: vi.fn(),
    }
  })

  it('calls onNext on j', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => fireKey('j'))
    expect(handlers.onNext).toHaveBeenCalledTimes(1)
  })

  it('calls onPrev on k', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => fireKey('k'))
    expect(handlers.onPrev).toHaveBeenCalledTimes(1)
  })

  it('calls onToggleRead on m', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => fireKey('m'))
    expect(handlers.onToggleRead).toHaveBeenCalledTimes(1)
  })

  it('calls onToggleStar on s', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => fireKey('s'))
    expect(handlers.onToggleStar).toHaveBeenCalledTimes(1)
  })

  it('handles g then a chord for go-all', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => { fireKey('g'); fireKey('a') })
    expect(handlers.onGoAll).toHaveBeenCalledTimes(1)
  })

  it('does not trigger g-a if keys are not sequential', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => { fireKey('g'); fireKey('x') })
    expect(handlers.onGoAll).not.toHaveBeenCalled()
  })

  it('calls onHelp on ?', () => {
    renderHook(() => useKeyboard(handlers))
    act(() => fireKey('?'))
    expect(handlers.onHelp).toHaveBeenCalledTimes(1)
  })
})
