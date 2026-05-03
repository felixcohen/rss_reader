import './ShortcutOverlay.css'

const SHORTCUTS = [
  ['j', 'Next item'],
  ['k', 'Previous item'],
  ['Space', 'Page down / next item'],
  ['Shift+Space', 'Page up'],
  ['a', 'Mark all as read'],
  ['m', 'Toggle read/unread'],
  ['s', 'Toggle star'],
  ['v', 'Open post in new tab'],
  ['r', 'Refresh feed'],
  ['g a', 'Go to All Items'],
  ['h / ?', 'Show/hide this overlay'],
]

export function ShortcutOverlay({ onClose }) {
  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="overlay-box" onClick={(e) => e.stopPropagation()}>
        <h2>Keyboard Shortcuts</h2>
        <table>
          <tbody>
            {SHORTCUTS.map(([key, desc]) => (
              <tr key={key}>
                <td><kbd>{key}</kbd></td>
                <td>{desc}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <button onClick={onClose}>Close</button>
      </div>
    </div>
  )
}
