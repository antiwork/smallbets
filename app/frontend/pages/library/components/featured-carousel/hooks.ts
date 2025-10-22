import { useEffect, useMemo, useRef, useState } from "react"
import type { CarouselApi } from "@/components/ui/carousel"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"

export interface DragBindings {
  onPointerDownCapture: React.PointerEventHandler<HTMLElement>
  onPointerMoveCapture: React.PointerEventHandler<HTMLElement>
  onPointerUpCapture: React.PointerEventHandler<HTMLElement>
  onPointerCancelCapture: React.PointerEventHandler<HTMLElement>
  onClickCapture: React.MouseEventHandler<HTMLElement>
}

export interface DragState {
  dragOffset: number
  isDragging: boolean
}

export function useSlides(
  sessions: LibrarySessionPayload[],
  thumbnails?: Record<string, VimeoThumbnailPayload>,
) {
  return useMemo(
    () =>
      sessions.map((session) => ({
        session,
        thumbnail: thumbnails?.[session.vimeoId],
      })),
    [sessions, thumbnails],
  )
}

export function useCarouselState(
  api: CarouselApi | undefined,
  fallbackCount: number,
) {
  const [current, setCurrent] = useState(0)
  const [count, setCount] = useState(fallbackCount)
  const [isReady, setIsReady] = useState(false)

  useEffect(() => {
    if (!api) return

    const syncState = () => {
      setCount(api.scrollSnapList().length)
      setCurrent(api.selectedScrollSnap())
    }

    syncState()
    api.on("select", syncState)
    return () => {
      api.off("select", syncState)
    }
  }, [api])

  useEffect(() => {
    if (count > 0 || fallbackCount > 0) setIsReady(true)
  }, [count, fallbackCount])

  return { current, count, isReady }
}

export function useDragNavigation(
  api: CarouselApi | undefined,
  thresholdPx = 100,
) {
  const [dragOffset, setDragOffset] = useState(0)
  const [isDragging, setIsDragging] = useState(false)

  const dragPointerIdRef = useRef<number | null>(null)
  const startXRef = useRef(0)
  const startYRef = useRef(0)
  const currentOffsetRef = useRef(0)
  const suppressClickRef = useRef(false)

  const onPointerDownCapture: React.PointerEventHandler<HTMLElement> = (e) => {
    if (e.button === 2) return

    // Don't intercept pointer events on elements marked as no-drag
    const target = e.target as HTMLElement
    if (target.closest('[data-no-drag="true"]')) {
      return
    }

    dragPointerIdRef.current = e.pointerId
    startXRef.current = e.clientX
    startYRef.current = e.clientY
    currentOffsetRef.current = 0
    suppressClickRef.current = false
  }

  const onPointerMoveCapture: React.PointerEventHandler<HTMLElement> = (e) => {
    if (dragPointerIdRef.current !== e.pointerId) return
    const dx = e.clientX - startXRef.current
    const dy = e.clientY - startYRef.current

    const DRAG_START_THRESHOLD = 10
    const draggingNow =
      isDragging ||
      (Math.abs(dx) > DRAG_START_THRESHOLD && Math.abs(dx) > Math.abs(dy))

    if (!isDragging && draggingNow) setIsDragging(true)

    if (draggingNow) {
      if (Math.abs(dx) >= thresholdPx) {
        if (dx < 0) api?.scrollNext()
        else api?.scrollPrev()
        dragPointerIdRef.current = null
        setIsDragging(false)
        setDragOffset(0)
        currentOffsetRef.current = 0
        suppressClickRef.current = true
        setTimeout(() => {
          suppressClickRef.current = false
        }, 100)
        return
      }

      currentOffsetRef.current = dx
      setDragOffset(dx)
    }
  }

  const onPointerUpOrCancelCapture: React.PointerEventHandler<HTMLElement> = (
    e,
  ) => {
    if (dragPointerIdRef.current !== e.pointerId) return
    const dx = currentOffsetRef.current
    const target = e.target as HTMLElement
    const isInteractive =
      target.closest("button") ||
      target.closest("a") ||
      target.closest('[role="button"]')

    if (isDragging) {
      if (dx < -thresholdPx) api?.scrollNext()
      else if (dx > thresholdPx) api?.scrollPrev()

      if (!isInteractive) {
        suppressClickRef.current = Math.abs(dx) > 10
      }

      setTimeout(() => {
        suppressClickRef.current = false
      }, 100)
    }

    dragPointerIdRef.current = null
    setIsDragging(false)
    setDragOffset(0)
    currentOffsetRef.current = 0
  }

  const onClickCapture: React.MouseEventHandler<HTMLElement> = (e) => {
    if (!suppressClickRef.current) return
    e.preventDefault()
    e.stopPropagation()
    suppressClickRef.current = false
  }

  return {
    bindings: {
      onPointerDownCapture,
      onPointerMoveCapture,
      onPointerUpCapture: onPointerUpOrCancelCapture,
      onPointerCancelCapture: onPointerUpOrCancelCapture,
      onClickCapture,
    },
    state: { dragOffset, isDragging },
  }
}
