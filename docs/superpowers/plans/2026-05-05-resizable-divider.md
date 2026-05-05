# Resizable Item/Article Divider + Unread Footer Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a draggable resize handle between the item list and article pane, and left-align the "N unread" footer text.

**Architecture:** `itemListWidth` state lives in `App`. A module-level `DragHandle` component handles the visual strip; drag logic lives in a `startDrag` callback in `App` that attaches/removes window listeners on the fly. CSS changes to `ItemList` swap `flex: 1` for `flex: none + explicit width`; `ArticlePane` keeps `flex: 1`.

**Tech Stack:** React 18, plain CSS, no new dependencies.

---

### Task 1: Fix unread footer alignment

**Files:**
- Modify: `frontend/src/components/ItemList.css`

This is a pure CSS change — no tests needed. The footer currently uses `justify-content: center`; we left-align it to match item row indent.

- [ ] **Step 1: Edit `.item-list-footer` in ItemList.css**

Find this rule:
```css
.item-list-footer { height: 32px; display: flex; align-items: center; justify-content: center; font-size: 12px; color: #aaa; border-top: 1px solid #eee; flex-shrink: 0; }
```

Change to:
```css
.item-list-footer { height: 32px; display: flex; align-items: center; justify-content: flex-start; padding-left: 14px; font-size: 12px; color: #aaa; border-top: 1px solid #eee; flex-shrink: 0; }
```

The `14px` matches `.item-row { padding: 10px 14px }` — purely visual alignment, not structural.

- [ ] **Step 2: Start the dev server and verify visually**

```bash
cd frontend && npm run dev
```

Open the app. The "N unread" text at the bottom of the item list should be left-aligned, indented ~14px from the left edge. Confirm it no longer appears centred.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/ItemList.css
git commit -m "fix: left-align unread footer to match item row indent"
```

---

### Task 2: Prepare ItemList for externally controlled width

**Files:**
- Modify: `frontend/src/components/ItemList.jsx`
- Modify: `frontend/src/components/ItemList.css`

`ItemList` currently owns its own width via `flex: 1` in CSS. We need to accept a `style` prop from `App` so `App` can set `width` directly. We also remove the `border-right` — the drag handle div will serve as the visual separator instead.

- [ ] **Step 1: Add `style` prop to ItemList**

In `frontend/src/components/ItemList.jsx`, find the function signature:
```jsx
export function ItemList({ items, selectedItemId, feeds, onSelect, onLoadMore, hasMore, unreadOnly, onToggleUnreadOnly, unreadCount }) {
```

Change to:
```jsx
export function ItemList({ items, selectedItemId, feeds, onSelect, onLoadMore, hasMore, unreadOnly, onToggleUnreadOnly, unreadCount, style }) {
```

Then find the root div:
```jsx
  return (
    <div className="item-list">
```

Change to:
```jsx
  return (
    <div className="item-list" style={style}>
```

- [ ] **Step 2: Update ItemList.css layout rules**

Find:
```css
.item-list { flex: 1; overflow: hidden; background: #fff; border-right: 1px solid #ddd; display: flex; flex-direction: column; }
```

Change to:
```css
.item-list { flex: none; height: 100%; overflow: hidden; background: #fff; display: flex; flex-direction: column; }
```

Key changes:
- `flex: 1` → `flex: none` — width now comes entirely from the inline `style` prop passed by App
- `height: 100%` added explicitly — ensures the react-window `calc(100% - 36px - 32px)` height calculation remains valid
- `border-right` removed — the drag handle div replaces it as the visual separator

- [ ] **Step 3: Verify the app still renders correctly (before wiring width state)**

The item list will currently have no width set (App hasn't passed a style prop yet). That's expected — it'll look broken temporarily. Just confirm no JS errors in the console.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/components/ItemList.jsx frontend/src/components/ItemList.css
git commit -m "refactor: accept style prop on ItemList for externally controlled width"
```

---

### Task 3: Add drag handle and wire up width state in App

**Files:**
- Modify: `frontend/src/App.jsx`
- Modify: `frontend/src/App.css`

This is the main task. We add `itemListWidth` state, a `DragHandle` component, and the `startDrag` callback.

- [ ] **Step 1: Add drag handle styles to App.css**

Append to `frontend/src/App.css`:
```css
.drag-handle {
  width: 4px;
  height: 100%;
  cursor: col-resize;
  background: #e0e0e0;
  flex-shrink: 0;
}
.drag-handle:hover { background: #bbb; }
```

- [ ] **Step 2: Add `DragHandle` component to App.jsx**

Add this **above** the `export default function App()` declaration (module level, not inside App):
```jsx
function DragHandle({ onMouseDown }) {
  return <div className="drag-handle" onMouseDown={onMouseDown} />
}
```

Placing it outside `App` prevents it remounting on every App render (which would reset hover state mid-drag).

- [ ] **Step 3: Add `itemListWidth` state and `startDrag` callback inside App**

Near the top of the `App` function body, after existing `useState` declarations, add:
```jsx
const [itemListWidth, setItemListWidth] = useState(360)

const SIDEBAR_WIDTH = 240 // must match .sidebar { width } in Sidebar.css

function startDrag(e) {
  document.body.style.userSelect = 'none'
  document.querySelector('.article-pane').style.pointerEvents = 'none'

  function onMove(e) {
    setItemListWidth(Math.max(200, Math.min(600, e.clientX - SIDEBAR_WIDTH)))
  }
  function onUp() {
    document.body.style.userSelect = ''
    document.querySelector('.article-pane').style.pointerEvents = ''
    window.removeEventListener('mousemove', onMove)
    window.removeEventListener('mouseup', onUp)
  }
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup', onUp)
}
```

`onMove` and `onUp` are defined inside `startDrag` so their closure captures make them the same function references for both `addEventListener` and `removeEventListener`. No ref needed. Listeners clean themselves up in `onUp` — no `useEffect` required.

`pointer-events: none` on `.article-pane` during drag prevents cursor flicker and dropped `mousemove` events when the mouse passes over rendered feed HTML (images, links, etc.).

- [ ] **Step 4: Render DragHandle and pass width to ItemList**

In the JSX returned by `App`, find:
```jsx
      <ItemList
        items={items}
```

Change the `<ItemList ... />` to include the style prop, and add `<DragHandle>` immediately after it:
```jsx
      <ItemList
        items={items}
        feeds={feeds}
        selectedItemId={selectedItem?.id}
        onSelect={selectItem}
        onLoadMore={loadMore}
        hasMore={!!nextBeforeId}
        unreadOnly={unreadOnly}
        onToggleUnreadOnly={() => setUnreadOnly((v) => !v)}
        unreadCount={selectedFeedId
          ? (feeds.find((f) => f.id === selectedFeedId)?.unread_count ?? 0)
          : feeds.reduce((sum, f) => sum + (f.unread_count ?? 0), 0)}
        style={{ width: itemListWidth }}
      />
      <DragHandle onMouseDown={startDrag} />
```

- [ ] **Step 5: Verify drag handle works**

In the running dev server:
1. A thin grey vertical strip should appear between the item list and article pane.
2. Hover over it — it darkens to `#bbb`.
3. Click and drag left/right — the item list should resize smoothly.
4. Drag to the left edge (~200px min) — item list stops shrinking.
5. Drag to the right (~600px max) — item list stops growing.
6. Release the mouse — no stray event listeners (check DevTools → Event Listeners on `window` — should be empty after release).
7. Drag over the article pane content (text, images) — no cursor flicker, drag remains smooth.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/App.jsx frontend/src/App.css
git commit -m "feat: add resizable drag handle between item list and article pane"
```

---

### Task 4: Add ArticlePane minimum width

**Files:**
- Modify: `frontend/src/components/ArticlePane.css`

A guard so the article pane can't be squeezed below 180px when the item list is dragged to its maximum (600px).

- [ ] **Step 1: Add `min-width` to `.article-pane`**

In `frontend/src/components/ArticlePane.css`, find:
```css
.article-pane {
  flex: 1;
  height: 100vh;
  overflow-y: auto;
  padding: 24px 32px;
  background: #fff;
  box-sizing: border-box;
}
```

Add `min-width: 180px;`:
```css
.article-pane {
  flex: 1;
  min-width: 180px;
  height: 100vh;
  overflow-y: auto;
  padding: 24px 32px;
  background: #fff;
  box-sizing: border-box;
}
```

- [ ] **Step 2: Final visual check**

Drag the handle to the far right (600px item list). The article pane should not collapse below 180px. The layout at 1024px viewport width should still look reasonable.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/ArticlePane.css
git commit -m "fix: add min-width to article pane to prevent over-compression"
```
