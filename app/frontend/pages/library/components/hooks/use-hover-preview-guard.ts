import { useCallback, useEffect, useRef } from "react"

interface HoverPreviewGuardOptions<T extends HTMLElement> {
  containerRef: React.RefObject<T | null>
  onStop: () => void
}

export function useHoverPreviewGuard<T extends HTMLElement>({
  containerRef,
  onStop,
}: HoverPreviewGuardOptions<T>) {
  const docListenersActiveRef = useRef(false)
  const lastPointerPosRef = useRef<{ x: number; y: number } | null>(null)

  const isPointerOverElement = useCallback(
    (x: number, y: number, el: HTMLElement): boolean => {
      const rect = el.getBoundingClientRect()
      return (
        x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
      )
    },
    [],
  )

  const stopIfPointerNotOver = useCallback(() => {
    const el = containerRef.current
    if (!el) return
    const pos = lastPointerPosRef.current
    if (!pos) return
    if (!isPointerOverElement(pos.x, pos.y, el)) {
      teardown()
      onStop()
    }
  }, [containerRef, isPointerOverElement, onStop])

  const onDocPointerMove = useCallback(
    (e: PointerEvent) => {
      lastPointerPosRef.current = { x: e.clientX, y: e.clientY }
      stopIfPointerNotOver()
    },
    [stopIfPointerNotOver],
  )

  const onDocScroll = useCallback(() => {
    stopIfPointerNotOver()
  }, [stopIfPointerNotOver])

  const onResize = useCallback(() => {
    stopIfPointerNotOver()
  }, [stopIfPointerNotOver])

  function setup() {
    if (docListenersActiveRef.current) return
    document.addEventListener("pointermove", onDocPointerMove as any, {
      capture: true,
      passive: true,
    })
    document.addEventListener("scroll", onDocScroll as any, {
      capture: true,
      passive: true,
    })
    window.addEventListener("resize", onResize as any)
    docListenersActiveRef.current = true
  }

  function teardown() {
    if (!docListenersActiveRef.current) return
    document.removeEventListener("pointermove", onDocPointerMove as any, true)
    document.removeEventListener("scroll", onDocScroll as any, true)
    window.removeEventListener("resize", onResize as any)
    docListenersActiveRef.current = false
  }

  useEffect(() => {
    return () => {
      teardown()
    }
  }, [])

  return { arm: setup, disarm: teardown }
}
