import { useEffect, useRef } from 'react'

export function useKeyboard(handlers) {
  const pendingG    = useRef(false)
  const handlersRef = useRef(handlers)

  useEffect(() => { handlersRef.current = handlers })

  useEffect(() => {
    function onKeyDown(e) {
      const h = handlersRef.current
      if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) return

      if (pendingG.current) {
        pendingG.current = false
        if (e.key === 'a') { h.onGoAll?.(); return }
      }

      switch (e.key) {
        case 'j':  h.onNext?.();       break
        case 'k':  h.onPrev?.();       break
        case 'm':  h.onToggleRead?.(); break
        case 's':  h.onToggleStar?.(); break
        case 'r':  h.onRefresh?.();    break
        case '?':  h.onHelp?.();       break
        case 'g':  pendingG.current = true; break
        case ' ':
          e.preventDefault()
          if (e.shiftKey) h.onShiftSpace?.()
          else            h.onSpace?.()
          break
        default: break
      }
    }

    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [])
}
