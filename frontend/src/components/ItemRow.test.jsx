import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { vi, describe, it, expect } from 'vitest'
import { ItemRow } from './ItemRow'

const baseItem = {
  id: 1,
  title: 'Hello World',
  feed_id: 10,
  published_at: '2026-01-15T12:00:00Z',
  is_read: false,
  is_starred: false,
  summary: 'A short summary of the article',
}

describe('ItemRow', () => {
  it('renders the item title', () => {
    render(<ItemRow item={baseItem} isSelected={false} feedTitle="Tech Feed" style={{}} onClick={vi.fn()} />)
    expect(screen.getByText('Hello World')).toBeInTheDocument()
  })

  it('renders feed title', () => {
    render(<ItemRow item={baseItem} isSelected={false} feedTitle="Tech Feed" style={{}} onClick={vi.fn()} />)
    expect(screen.getByText('Tech Feed')).toBeInTheDocument()
  })

  it('renders summary snippet', () => {
    render(<ItemRow item={baseItem} isSelected={false} feedTitle="" style={{}} onClick={vi.fn()} />)
    expect(screen.getByText(/A short summary/)).toBeInTheDocument()
  })

  it('has unread class when item is unread', () => {
    const { container } = render(
      <ItemRow item={{ ...baseItem, is_read: false }} isSelected={false} feedTitle="" style={{}} onClick={vi.fn()} />
    )
    expect(container.firstChild).toHaveClass('unread')
    expect(container.firstChild).not.toHaveClass('read')
  })

  it('has read class when item is read', () => {
    const { container } = render(
      <ItemRow item={{ ...baseItem, is_read: true }} isSelected={false} feedTitle="" style={{}} onClick={vi.fn()} />
    )
    expect(container.firstChild).toHaveClass('read')
    expect(container.firstChild).not.toHaveClass('unread')
  })

  it('has selected class when isSelected is true', () => {
    const { container } = render(
      <ItemRow item={baseItem} isSelected={true} feedTitle="" style={{}} onClick={vi.fn()} />
    )
    expect(container.firstChild).toHaveClass('selected')
  })

  it('does not have selected class when isSelected is false', () => {
    const { container } = render(
      <ItemRow item={baseItem} isSelected={false} feedTitle="" style={{}} onClick={vi.fn()} />
    )
    expect(container.firstChild).not.toHaveClass('selected')
  })

  it('calls onClick when clicked', () => {
    const onClick = vi.fn()
    render(<ItemRow item={baseItem} isSelected={false} feedTitle="" style={{}} onClick={onClick} />)
    fireEvent.click(screen.getByText('Hello World'))
    expect(onClick).toHaveBeenCalledTimes(1)
  })

  it('renders fallback title when item has no title', () => {
    render(<ItemRow item={{ ...baseItem, title: null }} isSelected={false} feedTitle="" style={{}} onClick={vi.fn()} />)
    expect(screen.getByText('(no title)')).toBeInTheDocument()
  })
})
