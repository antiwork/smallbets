import {
  forwardRef,
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from "react"
import type { LibrarySessionPayload, LibraryWatchPayload } from "../../../types"
import type { VimeoPlayerHandle } from "./types"
const LazyVimeoEmbed = lazy(async () =>
  import("./vimeo-embed").then((m) => ({ default: m.VimeoEmbed })),
)
import { ACTIVATION_ROOT_MARGIN, AUTOPLAY_PREVIEW_DELAY_MS } from "./constants"
import { preconnectVimeoOnce } from "../../../helpers/preconnect"
import { acquireMountSlot } from "./mount-queue"

interface VimeoPlayerProps {
  session: LibrarySessionPayload
  watchOverride?: LibraryWatchPayload | null
  onWatchUpdate?: (watch: LibraryWatchPayload) => void
  backIcon?: string
  persistPreview?: boolean
  onReady?: () => void
}

export const VimeoPlayer = forwardRef<VimeoPlayerHandle, VimeoPlayerProps>(
  function VimeoPlayer(
    {
      session,
      watchOverride,
      onWatchUpdate,
      backIcon,
      persistPreview,
      onReady,
    }: VimeoPlayerProps,
    ref,
  ) {
    const containerRef = useRef<HTMLDivElement | null>(null)
    const [isActivated, setIsActivated] = useState(false)
    const [canMount, setCanMount] = useState(false)
    const [shouldPlay, setShouldPlay] = useState(false)
    const [showControls, setShowControls] = useState(false)
    const [resetPreviewSignal, setResetPreviewSignal] = useState(0)
    const hoverTimerRef = useRef<number | null>(null)
    const hasAutoplayedRef = useRef(false)
    const releaseMountRef = useRef<null | (() => void)>(null)
    const instanceIdRef = useRef<string>(
      `vp_${Math.random().toString(36).slice(2)}`,
    )
    const PREVIEW_EVENT = "smallbets:preview-start"

    function isDataSaverEnabled(): boolean {
      try {
        const conn = (
          navigator as unknown as { connection?: { saveData?: boolean } }
        ).connection
        return Boolean(conn && conn.saveData)
      } catch (_e) {
        return false
      }
    }

    const playerSrc = useMemo(() => {
      try {
        const url = new URL(session.playerSrc)
        url.searchParams.set("controls", showControls ? "1" : "0")
        url.searchParams.set("fullscreen", "0")
        url.searchParams.set("muted", "1")
        // Match system appearance on initial load: black in dark, transparent in light
        let prefersDark = false
        try {
          if (typeof window !== "undefined" && "matchMedia" in window) {
            prefersDark = window.matchMedia(
              "(prefers-color-scheme: dark)",
            ).matches
          }
        } catch (_e) {
          // noop
        }
        url.searchParams.set("transparent", prefersDark ? "0" : "1")
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
        if (!isDataSaverEnabled()) setIsActivated(true)
        return
      }
      // Dynamic rootMargin based on connection quality
      let rootMargin = ACTIVATION_ROOT_MARGIN
      try {
        const et = (
          navigator as unknown as { connection?: { effectiveType?: string } }
        )?.connection?.effectiveType as string | undefined
        if (et && (et.includes("2g") || et.includes("3g"))) {
          rootMargin = "800px"
        }
      } catch (_e) {
        // noop
      }

      const observer = new IntersectionObserver(
        (entries) => {
          if (entries.some((entry) => entry.isIntersecting)) {
            if (!isDataSaverEnabled()) setIsActivated(true)
            preconnectVimeoOnce()
            void import("./vimeo-embed")
            observer.disconnect()
          }
        },
        { rootMargin },
      )
      observer.observe(element)
      return () => observer.disconnect()
    }, [isActivated])

    const handlePointerEnter = useCallback(() => {
      if (isDataSaverEnabled()) return
      if (!isActivated) setIsActivated(true)
      if (hoverTimerRef.current) window.clearTimeout(hoverTimerRef.current)
      if (hasAutoplayedRef.current) {
        // Announce start to stop other instances playing same video
        try {
          window.dispatchEvent(
            new CustomEvent(PREVIEW_EVENT, {
              detail: {
                vimeoId: session.vimeoId,
                sourceId: instanceIdRef.current,
              },
            } as CustomEventInit),
          )
        } catch (_e) {}
        setShouldPlay(true)
        return
      }
      hoverTimerRef.current = window.setTimeout(() => {
        hasAutoplayedRef.current = true
        hoverTimerRef.current = null
        try {
          window.dispatchEvent(
            new CustomEvent(PREVIEW_EVENT, {
              detail: {
                vimeoId: session.vimeoId,
                sourceId: instanceIdRef.current,
              },
            } as CustomEventInit),
          )
        } catch (_e) {}
        setShouldPlay(true)
      }, AUTOPLAY_PREVIEW_DELAY_MS)
      preconnectVimeoOnce()
      void import("./vimeo-embed")
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

    // Stop autoplay when window loses focus or becomes hidden
    useEffect(() => {
      function handleVisibilityChange() {
        if (document.hidden) {
          if (hoverTimerRef.current) {
            window.clearTimeout(hoverTimerRef.current)
            hoverTimerRef.current = null
          }
          setShouldPlay(false)
          if (isActivated) setResetPreviewSignal((value) => value + 1)
        }
      }

      function handleWindowBlur() {
        if (hoverTimerRef.current) {
          window.clearTimeout(hoverTimerRef.current)
          hoverTimerRef.current = null
        }
        setShouldPlay(false)
        if (isActivated) setResetPreviewSignal((value) => value + 1)
      }

      document.addEventListener("visibilitychange", handleVisibilityChange)
      window.addEventListener("blur", handleWindowBlur)

      return () => {
        document.removeEventListener("visibilitychange", handleVisibilityChange)
        window.removeEventListener("blur", handleWindowBlur)
      }
    }, [isActivated])

    useEffect(() => {
      setShowControls(false)
    }, [session.id])

    // Stop this preview when another preview starts anywhere
    useEffect(() => {
      const onPreviewStart = (e: Event) => {
        const ce = e as CustomEvent<{ vimeoId?: string; sourceId: string }>
        const detail = ce.detail
        if (!detail) return
        if (detail.sourceId === instanceIdRef.current) return
        if (hoverTimerRef.current) {
          window.clearTimeout(hoverTimerRef.current)
          hoverTimerRef.current = null
        }
        setShouldPlay(false)
        setResetPreviewSignal((value) => value + 1)
      }
      window.addEventListener(PREVIEW_EVENT, onPreviewStart)
      return () => window.removeEventListener(PREVIEW_EVENT, onPreviewStart)
    }, [])

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
      getCurrentWatch: () => {
        const watch = watchOverride ?? session.watch ?? null
        return watch
      },
    }))

    // Concurrency gating for mounting the iframe
    useEffect(() => {
      let cancelled = false
      if (isActivated && !canMount) {
        void acquireMountSlot().then((release) => {
          if (cancelled) {
            release()
            return
          }
          releaseMountRef.current = release
          setCanMount(true)
        })
      }
      return () => {
        cancelled = true
      }
    }, [isActivated, canMount])

    useEffect(() => {
      return () => {
        if (releaseMountRef.current) {
          releaseMountRef.current()
          releaseMountRef.current = null
        }
      }
    }, [])

    return (
      <div
        ref={containerRef}
        className="vimeo-fullscreen bg-background absolute inset-0"
      >
        {isActivated && canMount ? (
          <Suspense
            fallback={
              <div
                aria-hidden
                className="absolute inset-0 z-0 flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 opacity-80 motion-safe:animate-[pulse_8s_ease-in-out_infinite]"
              />
            }
          >
            <LazyVimeoEmbed
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
              onFrameLoad={() => {
                if (releaseMountRef.current) {
                  releaseMountRef.current()
                  releaseMountRef.current = null
                }
              }}
              onReady={onReady}
            />
          </Suspense>
        ) : (
          <div
            aria-hidden
            className="absolute inset-0 z-0 flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 opacity-80 motion-safe:animate-[pulse_8s_ease-in-out_infinite]"
          />
        )}
      </div>
    )
  },
)
