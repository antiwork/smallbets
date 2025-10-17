import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from "react"
import type { LibrarySessionPayload, LibraryWatchPayload } from "../../../types"
import type { VimeoPlayerHandle } from "./types"
import { VimeoEmbed } from "./vimeo-embed"
import { ACTIVATION_ROOT_MARGIN, AUTOPLAY_PREVIEW_DELAY_MS } from "./constants"

interface VimeoPlayerProps {
  session: LibrarySessionPayload
  watchOverride?: LibraryWatchPayload | null
  onWatchUpdate?: (watch: LibraryWatchPayload) => void
  backIcon?: string
  persistPreview?: boolean
}

const VimeoPlayer = forwardRef<VimeoPlayerHandle, VimeoPlayerProps>(
  function VimeoPlayer(
    {
      session,
      watchOverride,
      onWatchUpdate,
      backIcon,
      persistPreview,
    }: VimeoPlayerProps,
    ref,
  ) {
    const containerRef = useRef<HTMLDivElement | null>(null)
    const [isActivated, setIsActivated] = useState(false)
    const [shouldPlay, setShouldPlay] = useState(false)
    const [showControls, setShowControls] = useState(false)
    const [resetPreviewSignal, setResetPreviewSignal] = useState(0)
    const hoverTimerRef = useRef<number | null>(null)
    const hasAutoplayedRef = useRef(false)

    const playerSrc = useMemo(() => {
      try {
        const url = new URL(session.playerSrc)
        url.searchParams.set("controls", showControls ? "1" : "0")
        url.searchParams.set("fullscreen", "0")
        url.searchParams.set("muted", "1")
        return url.toString()
      } catch (_error) {
        return session.playerSrc
      }
    }, [session.playerSrc, showControls])

    useEffect(() => {
      if (isActivated) return
      if (typeof window === "undefined") return
      const element = containerRef.current
      if (!element) return
      if (!("IntersectionObserver" in window)) {
        setIsActivated(true)
        return
      }
      const observer = new IntersectionObserver(
        (entries) => {
          if (entries.some((entry) => entry.isIntersecting)) {
            setIsActivated(true)
            observer.disconnect()
          }
        },
        { rootMargin: ACTIVATION_ROOT_MARGIN },
      )
      observer.observe(element)
      return () => observer.disconnect()
    }, [isActivated])

    const handleActivate = useCallback(() => {
      if (isActivated) return
      setIsActivated(true)
      setShouldPlay(true)
      hasAutoplayedRef.current = true
    }, [isActivated])

    const handlePointerEnter = useCallback(() => {
      if (!isActivated) setIsActivated(true)
      if (hoverTimerRef.current) window.clearTimeout(hoverTimerRef.current)
      if (hasAutoplayedRef.current) {
        setShouldPlay(true)
        return
      }
      hoverTimerRef.current = window.setTimeout(() => {
        hasAutoplayedRef.current = true
        hoverTimerRef.current = null
        setShouldPlay(true)
      }, AUTOPLAY_PREVIEW_DELAY_MS)
    }, [isActivated])

    const handlePointerLeave = useCallback(() => {
      if (hoverTimerRef.current) {
        window.clearTimeout(hoverTimerRef.current)
        hoverTimerRef.current = null
      }
      setShouldPlay(false)
      if (isActivated) setResetPreviewSignal((value) => value + 1)
    }, [isActivated])

    useEffect(
      () => () => {
        if (hoverTimerRef.current) window.clearTimeout(hoverTimerRef.current)
      },
      [],
    )

    useEffect(() => {
      setShowControls(false)
    }, [session.id])

    useEffect(() => {
      if (!showControls) return
      const handleKey = (e: KeyboardEvent) => {
        if (e.key === "Escape") setShowControls(false)
      }
      document.addEventListener("keydown", handleKey)
      return () => document.removeEventListener("keydown", handleKey)
    }, [showControls])

    useEffect(() => {
      if (showControls) document.body.style.overflow = "hidden"
      else document.body.style.overflow = ""
      return () => {
        document.body.style.overflow = ""
      }
    }, [showControls])

    const enterFullscreen = useCallback(() => {
      if (!isActivated) {
        setIsActivated(true)
        setShouldPlay(true)
        hasAutoplayedRef.current = true
      }
      setShowControls(true)
      document.body.style.overflow = "hidden"
    }, [isActivated])

    useImperativeHandle(ref, () => ({
      enterFullscreen,
      startPreview: handlePointerEnter,
      stopPreview: handlePointerLeave,
    }))

    return (
      <div
        ref={containerRef}
        className="vimeo-fullscreen absolute inset-0 bg-black"
      >
        {isActivated ? (
          <VimeoEmbed
            session={session}
            shouldPlay={shouldPlay}
            playerSrc={playerSrc}
            isFullscreen={showControls}
            resetPreviewSignal={resetPreviewSignal}
            watchOverride={watchOverride}
            onWatchUpdate={onWatchUpdate}
            backIcon={backIcon}
            onExitFullscreen={() => setShowControls(false)}
            persistPreview={persistPreview}
          />
        ) : (
          <button
            type="button"
            aria-label={`Play ${session.title}`}
            onClick={handleActivate}
            className="group relative flex size-full items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 text-white"
          >
            <div className="relative flex size-14 items-center justify-center rounded-full bg-slate-900/80 transition group-hover:bg-slate-900">
              <svg
                aria-hidden
                viewBox="0 0 24 24"
                className="ms-1 size-6 fill-current"
              >
                <path d="M8 5.14v14l11-7-11-7z" />
              </svg>
            </div>
          </button>
        )}
      </div>
    )
  },
)

export default VimeoPlayer
