import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { vi, describe, it, expect } from 'vitest'
import { Sidebar } from './Sidebar'

const feeds = [
  { id: 1, title: 'Tech Feed',  url: 'https://a.com', unread_count: 5,  favicon_url: null },
  { id: 2, title: 'News Feed',  url: 'https://b.com', unread_count: 0,  favicon_url: null },
]
const groups = []

const defaultProps = {
  feeds,
  groups,
  selectedFeedId: null,
  onSelect: vi.fn(),
  onSelectAll: vi.fn(),
  onSelectStarred: vi.fn(),
  starredOnly: false,
  onAdmin: vi.fn(),
}

describe('Sidebar', () => {
  it('renders All Items button', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByText('All Items')).toBeInTheDocument()
  })

  it('renders feed titles', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByText('Tech Feed')).toBeInTheDocument()
    expect(screen.getByText('News Feed')).toBeInTheDocument()
  })

  it('shows unread badge for feeds with unread items', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByText('5')).toBeInTheDocument()
  })

  it('does not show unread badge when count is 0', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.queryByText('0')).not.toBeInTheDocument()
  })

  it('marks All Items as selected when no feed is selected and not starred', () => {
    const { container } = render(<Sidebar {...defaultProps} selectedFeedId={null} starredOnly={false} />)
    expect(container.querySelector('.sidebar-all')).toHaveClass('selected')
  })

  it('does not mark All Items as selected when a feed is selected', () => {
    const { container } = render(<Sidebar {...defaultProps} selectedFeedId={1} />)
    expect(container.querySelector('.sidebar-all')).not.toHaveClass('selected')
  })

  it('calls onSelectAll when All Items clicked', () => {
    const onSelectAll = vi.fn()
    render(<Sidebar {...defaultProps} onSelectAll={onSelectAll} />)
    fireEvent.click(screen.getByText('All Items'))
    expect(onSelectAll).toHaveBeenCalledTimes(1)
  })

  it('calls onSelect with feed id when feed clicked', () => {
    const onSelect = vi.fn()
    render(<Sidebar {...defaultProps} onSelect={onSelect} />)
    fireEvent.click(screen.getByText('Tech Feed'))
    expect(onSelect).toHaveBeenCalledWith(1)
  })

  it('renders Starred button', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByText(/Starred/)).toBeInTheDocument()
  })

  it('marks Starred as selected when starredOnly is true', () => {
    const { container } = render(<Sidebar {...defaultProps} starredOnly={true} />)
    expect(container.querySelector('.sidebar-starred')).toHaveClass('selected')
    expect(container.querySelector('.sidebar-all')).not.toHaveClass('selected')
  })

  it('calls onSelectStarred when Starred clicked', () => {
    const onSelectStarred = vi.fn()
    render(<Sidebar {...defaultProps} onSelectStarred={onSelectStarred} />)
    fireEvent.click(screen.getByText(/Starred/))
    expect(onSelectStarred).toHaveBeenCalledTimes(1)
  })

  it('calls onAdmin when gear button clicked', () => {
    const onAdmin = vi.fn()
    render(<Sidebar {...defaultProps} onAdmin={onAdmin} />)
    fireEvent.click(screen.getByTitle('Admin'))
    expect(onAdmin).toHaveBeenCalledTimes(1)
  })

  it('renders group label and feeds within group', () => {
    const groupFeeds  = [{ id: 3, title: 'Group Feed', url: 'https://c.com', unread_count: 0, favicon_url: null }]
    const withGroups  = [{ id: 10, name: 'Science', feed_ids: [3] }]
    render(<Sidebar {...defaultProps} feeds={[...feeds, ...groupFeeds]} groups={withGroups} />)
    expect(screen.getByText('Science')).toBeInTheDocument()
    expect(screen.getByText('Group Feed')).toBeInTheDocument()
  })
})
