# Resizable Item/Article Divider + Unread Footer Alignment

## Summary

Two small UI improvements to the three-panel reader layout:

1. A drag handle between the item list and article pane, letting the user resize those columns.
2. Left-align the "N unread" footer text to match item row indent.

## Drag Handle

### State

`itemListWidth` (number, default 360) in `App`. `flex: none` + explicit `style={{ width: itemListWidth }}` together are the sole width authority for `.item-list` — neither alone is sufficient.

### Width Application

`ItemList` accepts a `style` prop and spreads it onto its root `<div className="item-list">`. In `App.jsx`: `<ItemList style={{ width: itemListWidth }} ...>`. One-line change to `ItemList.jsx`.

`ArticlePane` keeps `flex: 1`.

### Drag Handle Implementation

- Defined as a **module-level component** `DragHandle` in `App.jsx` (outside the `App` function) to avoid remounting on every App render. Takes `onMouseDown` as a prop.
- Rendered as `<DragHandle onMouseDown={startDrag} />` between `<ItemList>` and `<ArticlePane>`.
- Styled in `App.css`: width 4px, height 100%, `cursor: col-resize`, background `#e0e0e0`, `:hover` background `#bbb`.

Drag logic in `App` as a `startDrag` callback:

```
const SIDEBAR_WIDTH = 240  // must match .sidebar { width } in Sidebar.css

function startDrag(e) {
  document.body.style.userSelect = 'none'
  document.querySelector('.article-pane').style.pointerEvents = 'none'

  function onMove(e) { setItemListWidth(Math.max(200, Math.min(600, e.clientX - SIDEBAR_WIDTH))) }
  function onUp()   {
    document.body.style.userSelect = ''
    document.querySelector('.article-pane').style.pointerEvents = ''
    window.removeEventListener('mousemove', onMove)
    window.removeEventListener('mouseup',   onUp)
  }
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup',   onUp)
}
```

`onMove` and `onUp` are defined inside `startDrag` so closure captures keep them in scope for removal — no ref needed. No separate cleanup `useEffect` is required because the listeners are always removed in `onUp`; navigate-away (e.g. to AdminPage) does not mount `DragHandle` at all.

`pointer-events: none` on `.article-pane` during drag prevents cursor flicker and lost `mousemove` events when dragging over rendered feed HTML.

### Layout Changes

- `ItemList.css`: `flex: 1` → `flex: none` on `.item-list`. Add `height: 100%` so the react-window `calc(100% - 36px - 32px)` height remains valid (flex children stretch to fill height by default, but explicit declaration prevents breakage under edge cases). Remove `border-right: 1px solid #ddd` — the drag handle is the visual separator.
- `ArticlePane.css`: add `min-width: 180px`. Leave existing `height: 100vh` alone (works within `overflow: hidden` flex container; out of scope to clean up).
- Clamp `[200, 600]`: at 600px item list, 240 + 600 + 4 = 844px, leaving 180px for ArticlePane = its `min-width`. `.app { min-width: 1024px }` prevents sub-1024px breakage.

## Unread Footer

In `ItemList.css`, on `.item-list-footer`:
- `justify-content: center` → `justify-content: flex-start`
- Add `padding-left: 14px` — matches the 14px left indent of `.item-row { padding: 10px 14px }`

## Files Changed

- `frontend/src/App.jsx` — `itemListWidth` state, `DragHandle` module-level component, `startDrag` callback, pass `style` to `<ItemList>`
- `frontend/src/App.css` — `.drag-handle` and `.drag-handle:hover` styles
- `frontend/src/components/ItemList.jsx` — accept and spread `style` prop onto root div
- `frontend/src/components/ItemList.css` — `.item-list`: `flex: none`, `height: 100%`, remove `border-right`; `.item-list-footer`: `flex-start`, `padding-left: 14px`
- `frontend/src/components/ArticlePane.css` — add `min-width: 180px`

## Out of Scope

- Persisting divider position across reloads
- Sidebar resize
