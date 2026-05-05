import React from 'react'
import './Modal.css'

export function Modal({ title, message, actions, onClose }) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-box" onClick={(e) => e.stopPropagation()}>
        {title && <h2>{title}</h2>}
        {message && <p>{message}</p>}
        <div className="modal-actions">
          {actions.map(({ label, variant, onClick }) => (
            <button
              key={label}
              className={`modal-btn ${variant || ''}`}
              onClick={onClick}
            >
              {label}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
