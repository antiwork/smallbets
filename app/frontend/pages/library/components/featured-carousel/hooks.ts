import { useEffect, useMemo, useRef, useState } from "react"
import type { CarouselApi } from "@/components/ui/carousel"
import type { LibrarySessionPayload } from "../../types"

const DEFAULT_AUTOPLAY_INTERVAL_MS = 6000
const MIN_AUTOPLAY_INTERVAL_MS = 1000
const DEFAULT_DRAG_THRESHOLD_PX = 100
const DRAG_ACTIVATION_THRESHOLD_PX = 10
const SUPPRESS_CLICK_RESET_MS = 100

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
  heroImagesById?: Record<string, string>,
) {
  return useMemo(
    () =>
      sessions.map((session) => ({
        session,
        imageSrc: heroImagesById?.[String(session.id)] ?? null,
      })),
    [sessions, heroImagesById],
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
  thresholdPx = DEFAULT_DRAG_THRESHOLD_PX,
  onInteract?: () => void,
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

    if (onInteract) onInteract()

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

    const draggingNow =
      isDragging ||
      (Math.abs(dx) > DRAG_ACTIVATION_THRESHOLD_PX &&
        Math.abs(dx) > Math.abs(dy))

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
        }, SUPPRESS_CLICK_RESET_MS)
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
      }, SUPPRESS_CLICK_RESET_MS)
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

export interface AutoplayControls {
  pause: () => void
  resume: () => void
  stop: () => void
  isPaused: boolean
  isStopped: boolean
}

export function useAutoplay(
  api: CarouselApi | undefined,
  options?: { intervalMs?: number },
): AutoplayControls {
  const intervalMs = Math.max(
    MIN_AUTOPLAY_INTERVAL_MS,
    options?.intervalMs ?? DEFAULT_AUTOPLAY_INTERVAL_MS,
  )

  const timerIdRef = useRef<number | null>(null)
  const isPausedRef = useRef(false)
  const isStoppedRef = useRef(false)
  const prefersReducedMotionRef = useRef(false)

  const [isPaused, setIsPaused] = useState(false)
  const [isStopped, setIsStopped] = useState(false)

  function clearTimer() {
    if (timerIdRef.current !== null) {
      window.clearTimeout(timerIdRef.current)
      timerIdRef.current = null
    }
  }

  function scheduleNext() {
    if (!api) return
    if (isPausedRef.current || isStoppedRef.current) return
    if (prefersReducedMotionRef.current) return
    if ((api.scrollSnapList()?.length ?? 0) < 2) return

    clearTimer()
    timerIdRef.current = window.setTimeout(() => {
      api?.scrollNext()
    }, intervalMs)
  }

  function pause() {
    isPausedRef.current = true
    setIsPaused(true)
    clearTimer()
  }

  function resume() {
    if (isStoppedRef.current) return
    isPausedRef.current = false
    setIsPaused(false)
    scheduleNext()
  }

  function stop() {
    isStoppedRef.current = true
    setIsStopped(true)
    clearTimer()
  }

  useEffect(() => {
    if (!api) return

    // initial schedule
    scheduleNext()

    const onSelect = () => {
      // restart the timer after any selection (user or programmatic)
      clearTimer()
      scheduleNext()
    }

    const onPointerDown = () => {
      // stop autoplay when the user starts interacting
      stop()
    }

    const onDestroy = () => {
      clearTimer()
    }

    api.on("select", onSelect)
    api.on("pointerDown", onPointerDown)
    api.on("destroy", onDestroy)

    return () => {
      api.off("select", onSelect)
      api.off("pointerDown", onPointerDown)
      api.off("destroy", onDestroy)
      clearTimer()
    }
  }, [api, intervalMs])

  useEffect(() => {
    // Respect prefers-reduced-motion
    const mql = window.matchMedia("(prefers-reduced-motion: reduce)")
    const handleChange = () => {
      prefersReducedMotionRef.current = mql.matches
      if (mql.matches) {
        clearTimer()
      } else if (!isPausedRef.current && !isStoppedRef.current) {
        scheduleNext()
      }
    }
    handleChange()
    mql.addEventListener("change", handleChange)
    return () => mql.removeEventListener("change", handleChange)
  }, [])

  useEffect(() => {
    const handleVisibility = () => {
      if (document.hidden) pause()
      else if (!isPausedRef.current && !isStoppedRef.current) scheduleNext()
    }
    document.addEventListener("visibilitychange", handleVisibility)
    return () =>
      document.removeEventListener("visibilitychange", handleVisibility)
  }, [])

  return { pause, resume, stop, isPaused, isStopped }
}
