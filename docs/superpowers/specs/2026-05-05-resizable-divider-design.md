# Resizable Item/Article Divider + Unread Footer Alignment

## Summary

Two small UI improvements to the three-panel reader layout:

1. A drag handle between the item list and article pane, letting the user resize those columns.
2. Left-align the "N unread" footer text to match item row indent.

## Drag Handle

### Approach

Add a custom drag handle — a thin vertical strip between `ItemList` and `ArticlePane` — implemented with React state and mouse events in `App.jsx`. No new dependencies.

### State

`itemListWidth` (number, default 360) held in `App`. Applied as `style={{ width: itemListWidth }}` on `ItemList`; `ArticlePane` keeps `flex: 1`.

### Drag Handle Component

- Inline in `App.jsx` (not a separate file — it's ~15 lines).
- A `<div>` with `cursor: col-resize`, width 4px, full height, styled in `App.css`.
- On `mousedown`: attach `mousemove` + `mouseup` listeners to `window`.
- On `mousemove`: compute new width from `clientX - sidebarWidth`. Clamp to `[200, 600]`.
- On `mouseup`: remove listeners.
- Visual: subtle border, hover highlight.

### Layout change

`ItemList` changes from `flex: 1` to explicit `width` via inline style. `flex-shrink: 0` added so it doesn't compress.

## Unread Footer

Change `justify-content: center` → `justify-content: flex-start` and add `padding-left: 14px` (matches `.item-row` padding) in `ItemList.css`.

## Files Changed

- `frontend/src/App.jsx` — add `itemListWidth` state, drag handle JSX, mouse event handlers
- `frontend/src/App.css` — drag handle styles
- `frontend/src/components/ItemList.css` — footer alignment fix
- `frontend/src/components/ItemList.jsx` — pass `width` style to item-list div, remove `flex: 1` from inline styles (it's already in CSS; just override via style prop)

## Out of Scope

- Persisting divider position across reloads (can add `localStorage` later).
- Sidebar resize (fixed at 240px).
