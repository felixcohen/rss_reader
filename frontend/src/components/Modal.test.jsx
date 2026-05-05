import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { vi, describe, it, expect } from 'vitest'
import { Modal } from './Modal'

describe('Modal', () => {
  it('renders title and message', () => {
    render(<Modal title="Confirm" message="Are you sure?" actions={[]} />)
    expect(screen.getByText('Confirm')).toBeInTheDocument()
    expect(screen.getByText('Are you sure?')).toBeInTheDocument()
  })

  it('renders action buttons', () => {
    const onOk = vi.fn()
    render(<Modal title="T" actions={[{ label: 'OK', onClick: onOk }, { label: 'Cancel', onClick: vi.fn() }]} />)
    expect(screen.getByText('OK')).toBeInTheDocument()
    expect(screen.getByText('Cancel')).toBeInTheDocument()
  })

  it('calls action onClick when button clicked', () => {
    const onOk = vi.fn()
    render(<Modal title="T" actions={[{ label: 'OK', onClick: onOk }]} />)
    fireEvent.click(screen.getByText('OK'))
    expect(onOk).toHaveBeenCalledTimes(1)
  })

  it('calls onClose when backdrop clicked', () => {
    const onClose = vi.fn()
    const { container } = render(
      <Modal title="T" actions={[]} onClose={onClose} />
    )
    fireEvent.click(container.querySelector('.modal-backdrop'))
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('does not call onClose when modal box clicked', () => {
    const onClose = vi.fn()
    const { container } = render(
      <Modal title="T" actions={[]} onClose={onClose} />
    )
    fireEvent.click(container.querySelector('.modal-box'))
    expect(onClose).not.toHaveBeenCalled()
  })

  it('omits title when not provided', () => {
    render(<Modal message="Just a message" actions={[]} />)
    expect(screen.queryByRole('heading')).not.toBeInTheDocument()
  })

  it('applies variant class to button', () => {
    render(<Modal title="T" actions={[{ label: 'Go', variant: 'primary', onClick: vi.fn() }]} />)
    expect(screen.getByText('Go')).toHaveClass('primary')
  })
})
