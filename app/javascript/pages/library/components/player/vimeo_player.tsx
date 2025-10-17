import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from "react"

import {
  getAutoplaySoundEnabled,
  setAutoplaySoundEnabled,
  subscribeToAutoplaySound,
} from "./autoplay_audio_pref"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

import {
  postWatchHistory,
  type WatchPayload,
  type WatchRequestOptions,
} from "./watch_history"

const ACTIVATION_ROOT_MARGIN = "200px"
const AUTOPLAY_PREVIEW_DELAY_MS = 1000
const MUTE_OVERLAY_HOLD_MS = 2500
const PROGRESS_THROTTLE_MS = 10_000

interface DownloadEntry {
  quality?: string
  link?: string
  width?: number
  height?: number
  size?: number
  size_short?: string
  type?: string
}

const downloadsCache: Map<string, DownloadEntry[]> = new Map()

interface VimeoPlayerProps {
  session: LibrarySessionPayload
  watchOverride?: LibraryWatchPayload | null
  onWatchUpdate?: (watch: LibraryWatchPayload) => void
}

interface LibrarySessionPayload {
  id: number
  title: string
  description: string
  padding: number
  creator: string
  thumbnailUrl?: string | null
  vimeoId: string
  vimeoHash?: string
  playerSrc: string
  downloadPath: string
  watchHistoryPath: string
  watch?: LibraryWatchPayload | null
}

interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

export interface VimeoPlayerHandle {
  enterFullscreen: () => void
  startPreview: () => void
  stopPreview: () => void
}

interface WritableRef<T> {
  current: T
}

type VimeoMessage =
  | { event: "ready" }
  | { event: "play" }
  | { event: "pause"; data?: PlaybackMetrics }
  | { event: "seeked"; data: PlaybackMetrics }
  | { event: "timeupdate"; data: { seconds: number; duration: number } }
  | { event: "ended" }

interface PlaybackMetrics {
  seconds: number
  duration: number
}

const TRACKED_EVENTS = [
  "play",
  "pause",
  "timeupdate",
  "seeked",
  "ended",
] as const

const VimeoPlayer = forwardRef<VimeoPlayerHandle, VimeoPlayerProps>(
  function VimeoPlayer(
    { session, watchOverride, onWatchUpdate }: VimeoPlayerProps,
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

      return () => {
        observer.disconnect()
      }
    }, [isActivated])

    const handleActivate = useCallback(() => {
      if (isActivated) return
      setIsActivated(true)
      setShouldPlay(true)
      hasAutoplayedRef.current = true
    }, [isActivated])

    const handlePointerEnter = useCallback(() => {
      if (!isActivated) {
        setIsActivated(true)
      }
      if (hoverTimerRef.current) {
        window.clearTimeout(hoverTimerRef.current)
      }
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
      if (isActivated) {
        setResetPreviewSignal((value) => value + 1)
      }
    }, [isActivated])

    useEffect(() => {
      return () => {
        if (hoverTimerRef.current) {
          window.clearTimeout(hoverTimerRef.current)
        }
      }
    }, [])

    useEffect(() => {
      setShowControls(false)
    }, [session.id])

    // Close on Escape when in full-window mode
    useEffect(() => {
      if (!showControls) return
      const handleKey = (e: KeyboardEvent) => {
        if (e.key === "Escape") setShowControls(false)
      }
      document.addEventListener("keydown", handleKey)
      return () => document.removeEventListener("keydown", handleKey)
    }, [showControls])

    // Lock scroll while full-window is active and restore on close/unmount
    useEffect(() => {
      if (showControls) {
        document.body.style.overflow = "hidden"
      } else {
        document.body.style.overflow = ""
      }
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
        onMouseEnter={handlePointerEnter}
        onMouseLeave={handlePointerLeave}
        onFocusCapture={handlePointerEnter}
        onBlurCapture={handlePointerLeave}
      >
        {isActivated ? (
          <ActiveVimeoPlayer
            session={session}
            shouldPlay={shouldPlay}
            playerSrc={playerSrc}
            isFullscreen={showControls}
            resetPreviewSignal={resetPreviewSignal}
            watchOverride={watchOverride}
            onWatchUpdate={onWatchUpdate}
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
        {!showControls && (
          <button
            type="button"
            aria-label={`Open ${session.title} in full screen`}
            onClick={enterFullscreen}
            className="absolute inset-0 z-10 cursor-pointer opacity-0"
          />
        )}
      </div>
    )
  },
)

export default VimeoPlayer

interface ActiveVimeoPlayerProps {
  session: LibrarySessionPayload
  shouldPlay: boolean
  playerSrc: string
  isFullscreen: boolean
  resetPreviewSignal: number
  watchOverride?: LibraryWatchPayload | null
  onWatchUpdate?: (watch: LibraryWatchPayload) => void
}

function ActiveVimeoPlayer({
  session,
  shouldPlay,
  playerSrc,
  isFullscreen,
  resetPreviewSignal,
  watchOverride,
  onWatchUpdate,
}: ActiveVimeoPlayerProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null)
  const [isReady, setIsReady] = useState(false)
  const [status, setStatus] = useState<PlaybackStatus>({ state: "idle" })
  const [autoplaySoundEnabled, setAutoplaySoundState] = useState(
    getAutoplaySoundEnabled(),
  )
  const progressRef = useRef<WatchPayload | null>(
    watchOverride ?? session.watch ?? null,
  )
  const fallbackOriginRef = useRef<string>(new URL(playerSrc).origin)
  const vimeoOriginRef = useRef<string | null>(null)
  const fullscreenStateRef = useRef(isFullscreen)
  const previousFullscreenRef = useRef(isFullscreen)
  const pendingPreviewResetRef = useRef(false)
  const lastPreviewResetSignalRef = useRef(resetPreviewSignal)
  const hasPersistedHistoryRef = useRef((session.watch?.playedSeconds ?? 0) > 0)
  const [isButtonHovered, setIsButtonHovered] = useState(false)
  const [isBgVisible, setIsBgVisible] = useState(false)
  const bgHoldTimerRef = useRef<number | null>(null)
  const overlayVisible = isBgVisible || isButtonHovered
  const overlayDurationClass = overlayVisible
    ? "before:duration-150" // fade-in
    : "before:duration-500" // fade-out

  const watchPath = session.watchHistoryPath

  const markHistoryPersisted = useCallback(() => {
    hasPersistedHistoryRef.current = true
  }, [])

  const throttler = useMemo(
    () =>
      createProgressThrottler(PROGRESS_THROTTLE_MS, (payload, options) => {
        void persistProgress(watchPath, payload, setStatus, options).then(
          (success) => {
            if (success) {
              markHistoryPersisted()
              if (onWatchUpdate) onWatchUpdate(payload)
            }
          },
        )
      }),
    [markHistoryPersisted, watchPath, onWatchUpdate],
  )

  useEffect(() => {
    progressRef.current = watchOverride ?? session.watch ?? null
  }, [watchOverride, session.watch])

  useEffect(() => {
    hasPersistedHistoryRef.current = (session.watch?.playedSeconds ?? 0) > 0
  }, [session.watch])

  useEffect(() => {
    fallbackOriginRef.current = new URL(playerSrc).origin
    vimeoOriginRef.current = null
    setIsReady(false)
  }, [playerSrc])

  useEffect(() => {
    fullscreenStateRef.current = isFullscreen
  }, [isFullscreen])

  const resetPreviewPlayback = useCallback(() => {
    const frame = frameRef.current
    if (!frame) return

    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "pause" },
      { fallbackOrigin: fallbackOriginRef.current },
    )
    const resumeAt = progressRef.current?.playedSeconds ?? 0
    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "setCurrentTime", value: resumeAt },
      { fallbackOrigin: fallbackOriginRef.current },
    )

    pendingPreviewResetRef.current = false
  }, [session.watch?.playedSeconds])

  useEffect(() => {
    if (
      resetPreviewSignal === lastPreviewResetSignalRef.current &&
      !pendingPreviewResetRef.current
    ) {
      return
    }

    if (fullscreenStateRef.current) return

    if (resetPreviewSignal !== lastPreviewResetSignalRef.current) {
      lastPreviewResetSignalRef.current = resetPreviewSignal
      pendingPreviewResetRef.current = true
    }

    if (isReady && pendingPreviewResetRef.current) {
      resetPreviewPlayback()
    }
  }, [resetPreviewSignal, isReady, resetPreviewPlayback])

  const handleVimeoMessage = useCallback(
    (message: VimeoMessage) => {
      setStatus((current) =>
        current.state === "error" ? current : { state: "idle" },
      )

      switch (message.event) {
        case "ready": {
          subscribeToEvents(
            frameRef.current,
            vimeoOriginRef,
            fallbackOriginRef.current,
          )
          setIsReady(true)
          break
        }
        case "timeupdate": {
          const next: WatchPayload = {
            playedSeconds: message.data.seconds,
            durationSeconds: message.data.duration,
            completed: false,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (fullscreenStateRef.current) {
            throttler.queue(next)
          }
          break
        }
        case "seeked": {
          const next: WatchPayload = {
            playedSeconds: message.data.seconds,
            durationSeconds: message.data.duration,
            completed: false,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (fullscreenStateRef.current) {
            throttler.flush(next)
          }
          break
        }
        case "pause": {
          const metrics = message.data
          if (metrics) {
            const next: WatchPayload = {
              playedSeconds: metrics.seconds,
              durationSeconds: metrics.duration,
              completed: false,
              lastWatchedAt: new Date().toISOString(),
            }
            progressRef.current = next
          }
          if (fullscreenStateRef.current) {
            throttler.flush(progressRef.current ?? undefined)
          }
          break
        }
        case "ended": {
          const duration =
            progressRef.current?.durationSeconds ??
            progressRef.current?.playedSeconds ??
            0
          const next: WatchPayload = {
            playedSeconds: duration,
            durationSeconds: duration,
            completed: true,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (fullscreenStateRef.current) {
            throttler.flush(next)
          }
          break
        }
        default: {
          break
        }
      }
    },
    [throttler],
  )

  useEffect(() => {
    const frame = frameRef.current
    if (!frame) return

    const handleMessage = (event: MessageEvent) => {
      if (
        !isVimeoEvent(event, frame, vimeoOriginRef, fallbackOriginRef.current)
      )
        return

      const payload = normalizeData(event.data)
      if (!payload) return

      handleVimeoMessage(payload)
    }

    window.addEventListener("message", handleMessage)
    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "ping" },
      {
        allowWildcard: true,
        fallbackOrigin: fallbackOriginRef.current,
      },
    )

    return () => {
      window.removeEventListener("message", handleMessage)
    }
  }, [handleVimeoMessage, playerSrc])

  useEffect(() => {
    if (previousFullscreenRef.current && !isFullscreen) {
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
    }
    previousFullscreenRef.current = isFullscreen
  }, [isFullscreen, throttler])

  useEffect(() => {
    function flushWithKeepalive(): void {
      if (!fullscreenStateRef.current) return
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
    }

    const handleVisibilityChange = () => {
      if (document.visibilityState !== "hidden") return
      flushWithKeepalive()
    }

    const handlePageHide = () => {
      flushWithKeepalive()
    }

    const handleBeforeUnload = () => {
      flushWithKeepalive()
    }

    document.addEventListener("visibilitychange", handleVisibilityChange)
    window.addEventListener("pagehide", handlePageHide)
    window.addEventListener("beforeunload", handleBeforeUnload)

    return () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange)
      window.removeEventListener("pagehide", handlePageHide)
      window.removeEventListener("beforeunload", handleBeforeUnload)
    }
  }, [throttler])

  useEffect(() => {
    return () => {
      if (fullscreenStateRef.current) {
        throttler.flush(progressRef.current ?? undefined, { keepalive: true })
      }
      throttler.cancel()
    }
  }, [throttler])

  useEffect(() => {
    const resumeAt = progressRef.current?.playedSeconds
    if (!isReady || resumeAt == null || !frameRef.current) return

    postToVimeo(frameRef.current, vimeoOriginRef, {
      method: "setCurrentTime",
      value: resumeAt,
    })
  }, [isReady])

  useEffect(() => {
    const unsubscribe = subscribeToAutoplaySound((enabled) => {
      setAutoplaySoundState(enabled)
    })

    return () => {
      unsubscribe()
    }
  }, [])

  // Manage background visibility lifecycle for the mute/unmute button
  useEffect(() => {
    if (isFullscreen) {
      // No button in fullscreen
      setIsBgVisible(false)
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
      return
    }

    // Only show once autoplay (preview) actually begins
    if (!shouldPlay) {
      setIsBgVisible(false)
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
      return
    }

    // Button just appeared because autoplay started
    setIsBgVisible(true)

    if (!isButtonHovered) {
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
      }
      bgHoldTimerRef.current = window.setTimeout(() => {
        setIsBgVisible(false)
        bgHoldTimerRef.current = null
      }, MUTE_OVERLAY_HOLD_MS)
    }

    return () => {
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
    }
  }, [shouldPlay, isFullscreen, isButtonHovered])

  const handleButtonEnter = useCallback(() => {
    setIsButtonHovered(true)
    setIsBgVisible(true)
    if (bgHoldTimerRef.current) {
      window.clearTimeout(bgHoldTimerRef.current)
      bgHoldTimerRef.current = null
    }
  }, [])

  const handleButtonLeave = useCallback(() => {
    setIsButtonHovered(false)
    if (!shouldPlay || isFullscreen) return
    if (bgHoldTimerRef.current) {
      window.clearTimeout(bgHoldTimerRef.current)
    }
    bgHoldTimerRef.current = window.setTimeout(() => {
      setIsBgVisible(false)
      bgHoldTimerRef.current = null
    }, MUTE_OVERLAY_HOLD_MS)
  }, [shouldPlay, isFullscreen])

  const syncVolume = useCallback(
    (frame: HTMLIFrameElement | null) => {
      if (!isReady || !frame) return
      const enableSound = isFullscreen || autoplaySoundEnabled

      postToVimeo(
        frame,
        vimeoOriginRef,
        {
          method: "setVolume",
          value: enableSound ? 1 : 0,
        },
        { fallbackOrigin: fallbackOriginRef.current },
      )
    },
    [autoplaySoundEnabled, isFullscreen, isReady],
  )

  useEffect(() => {
    syncVolume(frameRef.current)
  }, [syncVolume])

  useEffect(() => {
    const frame = frameRef.current
    if (!isReady || !frame) return

    if (shouldPlay) {
      syncVolume(frame)
    }

    postToVimeo(frame, vimeoOriginRef, {
      method: shouldPlay ? "play" : "pause",
    })
  }, [isReady, shouldPlay, syncVolume])

  useEffect(() => {
    // Ensure fullscreen always uses sound on
    syncVolume(frameRef.current)
  }, [isFullscreen, syncVolume])

  const toggleAutoplaySound = useCallback(() => {
    setAutoplaySoundEnabled(!autoplaySoundEnabled)
  }, [autoplaySoundEnabled])

  return (
    <div className="relative size-full bg-black">
      {!isReady && (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-gradient-to-br from-slate-900 to-slate-800"></div>
      )}
      {isFullscreen ? (
        <div
          className="fixed inset-0 z-[999] flex flex-col bg-black"
          style={{ ["--bar-h" as any]: "72px" }}
        >
          <div className="flex flex-1 items-center justify-center">
            <iframe
              ref={frameRef}
              title={session.title}
              src={playerSrc}
              className="vimeo-embed h-auto max-h-[calc(100vh-var(--bar-h))] w-[100vw]"
              style={{ aspectRatio: "16 / 9" }}
              allow="autoplay; picture-in-picture; clipboard-write"
              loading="lazy"
              referrerPolicy="strict-origin-when-cross-origin"
            />
          </div>
          <FullscreenInfoBar
            title={session.title}
            creator={session.creator}
            vimeoId={session.vimeoId}
            downloadPath={session.downloadPath}
          />
        </div>
      ) : (
        <div className="absolute inset-0">
          <iframe
            ref={frameRef}
            title={session.title}
            src={playerSrc}
            className="vimeo-embed size-full"
            allow="autoplay; picture-in-picture; clipboard-write"
            loading="lazy"
            referrerPolicy="strict-origin-when-cross-origin"
          />
        </div>
      )}
      {!isFullscreen && shouldPlay && (
        <button
          type="button"
          aria-pressed={autoplaySoundEnabled}
          aria-label={autoplaySoundEnabled ? "Mute" : "Unmute"}
          onClick={toggleAutoplaySound}
          onMouseEnter={handleButtonEnter}
          onMouseLeave={handleButtonLeave}
          className={[
            "absolute top-2.5 right-2.5 z-20 flex size-9 items-center justify-center overflow-hidden rounded-full text-white hover:shadow-none!",
            "before:pointer-events-none before:absolute before:inset-0 before:rounded-full before:bg-black before:transition-opacity before:ease-out before:content-['']",
            overlayDurationClass,
            overlayVisible ? "before:opacity-60" : "before:opacity-0",
          ].join(" ")}
        >
          {autoplaySoundEnabled ? (
            <svg
              viewBox="0 0 40 40"
              className="relative z-10 size-8 drop-shadow-[0_1px_1px_rgba(0,0,0,0.6)]"
            >
              <path
                d="M6 17.6469V22.6307C6 24.4433 7.46986 25.9174 9.28676 25.9174H12.5001V14.3616H9.28676C7.47412 14.3616 6 15.8315 6 17.6484V17.6469Z"
                fill="white"
              />
              <path
                d="M20.466 9.70226L13.9446 14.36V25.9158L20.466 30.5735C21.9684 31.6456 24.0561 30.5735 24.0561 28.7284V11.5471C24.0561 9.70197 21.9684 8.63021 20.466 9.70226Z"
                fill="white"
              />
              <path
                d="M27.5105 14.9944C27.136 14.6199 26.5294 14.6199 26.1561 14.9944C25.7816 15.3689 25.7816 15.9756 26.1561 16.3488C27.3033 17.496 27.9324 19.0202 27.9324 20.6406C27.9324 22.2608 27.2995 23.7888 26.1561 24.9323C25.7816 25.3068 25.7816 25.9135 26.1561 26.2867C26.3446 26.4752 26.588 26.5676 26.8339 26.5676C27.0798 26.5676 27.3258 26.4752 27.5118 26.2867C29.0197 24.7787 29.8511 22.7715 29.8511 20.6368C29.8511 18.5022 29.0197 16.495 27.5118 14.987L27.5105 14.9944Z"
                fill="white"
              />
              <path
                d="M28.8663 12.2845C28.4918 12.659 28.4918 13.2657 28.8663 13.6389C32.7298 17.5024 32.7298 23.785 28.8663 27.6486C28.4918 28.0231 28.4918 28.6297 28.8663 29.003C29.0548 29.1915 29.2982 29.2838 29.5441 29.2838C29.7901 29.2838 30.036 29.1915 30.222 29.003C34.8333 24.3917 34.8333 16.8922 30.222 12.2809C29.8475 11.9064 29.2408 11.9064 28.8676 12.2809L28.8663 12.2845Z"
                fill="white"
              />
            </svg>
          ) : (
            <svg
              viewBox="0 0 40 40"
              className="relative z-10 size-8 drop-shadow-[0_1px_1px_rgba(0,0,0,0.6)]"
            >
              <path
                d="M6 17.6469V22.6307C6 24.4433 7.46986 25.9174 9.28676 25.9174H12.5001V14.3616H9.28676C7.47412 14.3616 6 15.8315 6 17.6484V17.6469Z"
                fill="white"
              />
              <path
                d="M20.466 9.70226L13.9446 14.36V25.9158L20.466 30.5735C21.9684 31.6456 24.0561 30.5735 24.0561 28.7284V11.5471C24.0561 9.70197 21.9684 8.63021 20.466 9.70226Z"
                fill="white"
              />
              <path
                d="M31.9059 20.1378L34.2094 17.8343C34.6326 17.4111 34.6326 16.7255 34.2094 16.3037C33.7862 15.8805 33.1007 15.8805 32.6789 16.3037L30.3753 18.6073L28.0718 16.3037C27.6486 15.8805 26.9631 15.8805 26.5413 16.3037C26.1181 16.7269 26.1181 17.4125 26.5413 17.8343L28.8448 20.1378L26.5413 22.4413C26.1181 22.8645 26.1181 23.5501 26.5413 23.9719C26.7543 24.1849 27.0294 24.2893 27.3072 24.2893C27.5851 24.2893 27.863 24.1849 28.0732 23.9719L30.3768 21.6683L32.6803 23.9719C32.8933 24.1849 33.1684 24.2893 33.4463 24.2893C33.7242 24.2893 34.0021 24.1849 34.2122 23.9719C34.6354 23.5487 34.6354 22.8631 34.2122 22.4413L31.9087 20.1378H31.9059Z"
                fill="white"
              />
            </svg>
          )}
        </button>
      )}
      <StatusIndicator status={status} />
    </div>
  )
}

interface FullscreenInfoBarProps {
  title: string
  creator: string
  vimeoId: string
  downloadPath?: string
  defaultHref?: string
}

function FullscreenInfoBar({
  title,
  creator,
  vimeoId,
  downloadPath,
}: FullscreenInfoBarProps) {
  return (
    <div className="flex h-[var(--bar-h)] items-center justify-between border-t border-white/10 bg-black/95 px-4 pb-[calc(env(safe-area-inset-bottom))] text-white md:px-6">
      <div className="min-w-0 pr-3">
        <div className="truncate text-[clamp(0.95rem,1.2vw,1.25rem)] font-medium">
          {title}
        </div>
        <div className="truncate text-[clamp(0.8rem,0.95vw,1rem)] text-gray-300">
          {creator}
        </div>
      </div>
      <DownloadMenu
        vimeoId={vimeoId}
        downloadPath={downloadPath}
        title={title}
      />
    </div>
  )
}

interface DownloadMenuProps {
  vimeoId: string
  downloadPath?: string
  title: string
}

function DownloadMenu({ vimeoId, downloadPath, title }: DownloadMenuProps) {
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [entries, setEntries] = useState<DownloadEntry[]>([])
  const portalRef = useRef<HTMLDivElement | null>(null)

  // Type guard for API entries
  const isDownloadEntry = useCallback((d: unknown): d is DownloadEntry => {
    return (
      !!d &&
      typeof d === "object" &&
      ("quality" in (d as Record<string, unknown>) ||
        "link" in (d as Record<string, unknown>))
    )
  }, [])

  // Prefetch on mount (when the fullscreen overlay appears)
  useEffect(() => {
    if (entries.length > 0 || loading || error) return

    const cached = downloadsCache.get(vimeoId)
    if (cached) {
      setEntries(cached)
      return
    }

    setLoading(true)
    fetch(`/library/downloads/${vimeoId}`, {
      headers: { Accept: "application/json" },
    })
      .then((r) =>
        r.ok ? r.json() : Promise.reject(new Error(String(r.status))),
      )
      .then((json: unknown) => {
        const list = Array.isArray(json)
          ? (json.filter(isDownloadEntry) as DownloadEntry[])
          : []
        downloadsCache.set(vimeoId, list)
        setEntries(list)
        setError(list.length === 0 ? "No options" : null)
      })
      .catch(() => setError("Unable to load"))
      .finally(() => setLoading(false))
  }, [vimeoId, entries.length, loading, error, isDownloadEntry])

  function hrefFor(download: DownloadEntry): string | null {
    if (download.quality) {
      const url = new URL(
        `/library/download/${vimeoId}`,
        window.location.origin,
      )
      url.searchParams.set("quality", download.quality)
      return url.toString()
    }
    return download.link || downloadPath || null
  }

  function qualityLabel(download: DownloadEntry): string {
    if (download.quality) return String(download.quality).toUpperCase()
    if (download.type) return String(download.type).toUpperCase()
    return `Download (${title})`
  }

  function details(download: DownloadEntry): string {
    const parts: string[] = []
    const w = download.width
    const h = download.height
    if (w && h) parts.push(`${w}×${h}`)
    const short = download.size_short
    const size = Number(download.size)
    if (short) parts.push(short)
    else if (Number.isFinite(size) && size > 0) {
      const units = ["B", "KB", "MB", "GB", "TB"]
      let value = size
      let i = 0
      while (value >= 1024 && i < units.length - 1) {
        value /= 1024
        i += 1
      }
      parts.push(`${value.toFixed(value >= 10 ? 0 : 1)} ${units[i]}`)
    }
    return parts.join(" • ")
  }

  return (
    <div className="relative z-50 shrink-0" ref={portalRef}>
      <DropdownMenu modal={false} open={open} onOpenChange={setOpen}>
        <DropdownMenuTrigger asChild>
          <Button variant="secondary" className="border border-[#555]">
            Download
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent
          container={portalRef.current}
          side="top"
          align="end"
          sideOffset={8}
          className="w-64 border border-white/10 bg-black/95 text-white shadow-lg"
        >
          {loading && (
            <div className="px-2 py-1.5 text-sm select-none">Loading…</div>
          )}
          {error && (
            <a
              href={downloadPath || undefined}
              target="_blank"
              rel="nofollow noopener"
              className="block px-2 py-1.5 text-sm"
            >
              Error loading download options
            </a>
          )}
          {!loading &&
            !error &&
            entries.map((d, idx) => {
              const href = hrefFor(d)
              return (
                <DropdownMenuItem
                  key={idx}
                  onSelect={(e) => {
                    e.preventDefault()
                    if (!href) return
                    try {
                      window.open(href, "_blank", "noopener,noreferrer")
                    } catch {
                      // ignore
                    }
                    setOpen(false)
                  }}
                >
                  <div className="flex w-full cursor-pointer items-center justify-between gap-2">
                    <span className="text-sm">{qualityLabel(d)}</span>
                    <span className="text-muted-foreground text-xs">
                      {details(d)}
                    </span>
                  </div>
                </DropdownMenuItem>
              )
            })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}

function isVimeoEvent(
  event: MessageEvent,
  frame: HTMLIFrameElement,
  originRef: WritableRef<string | null>,
  fallbackOrigin: string,
): boolean {
  if (event.source !== frame.contentWindow) return false
  if (event.origin) {
    originRef.current = event.origin
  }
  if (!originRef.current) {
    originRef.current = fallbackOrigin
  }
  return true
}

function normalizeData(data: unknown): VimeoMessage | null {
  try {
    if (typeof data === "string") {
      return JSON.parse(data) as VimeoMessage
    }

    if (typeof data === "object" && data !== null) {
      return data as VimeoMessage
    }
  } catch (_error) {
    return null
  }

  return null
}

interface PostOptions {
  allowWildcard?: boolean
  fallbackOrigin?: string
}

function postToVimeo(
  frame: HTMLIFrameElement,
  originRef: WritableRef<string | null>,
  payload: Record<string, unknown>,
  options: PostOptions = {},
) {
  if (!frame.contentWindow) return

  const targetOrigin = resolveOrigin(originRef, options.fallbackOrigin)
  if (!targetOrigin) return

  frame.contentWindow.postMessage(
    payload,
    options.allowWildcard ? "*" : targetOrigin,
  )
}

function resolveOrigin(
  originRef: WritableRef<string | null>,
  fallbackOrigin?: string,
): string | null {
  if (originRef.current) return originRef.current
  if (fallbackOrigin) return fallbackOrigin
  return null
}

function subscribeToEvents(
  frame: HTMLIFrameElement | null,
  originRef: WritableRef<string | null>,
  fallbackOrigin: string,
) {
  if (!frame?.contentWindow) return

  TRACKED_EVENTS.forEach((event) => {
    postToVimeo(
      frame,
      originRef,
      {
        method: "addEventListener",
        value: event,
      },
      { fallbackOrigin },
    )
  })
}

type PlaybackStatus =
  | { state: "idle" }
  | { state: "saving" }
  | { state: "error"; message: string }

async function persistProgress(
  url: string,
  payload: LibraryWatchPayload,
  setStatus: (status: PlaybackStatus) => void,
  options: WatchRequestOptions = {},
) {
  setStatus({ state: "saving" })

  const result = await postWatchHistory(url, payload, options)

  if (!result.ok) {
    setStatus({
      state: "error",
      message: result.message ?? "Unable to save progress",
    })
    return false
  }

  setStatus({ state: "idle" })
  return true
}

function StatusIndicator({ status }: { status: PlaybackStatus }) {
  if (status.state === "idle") return null

  if (status.state === "error") {
    return (
      <div className="pointer-events-none absolute right-3 bottom-3 rounded-xl bg-red-900/90 px-3 py-2 text-xs font-medium text-white shadow">
        {status.message}
      </div>
    )
  }

  return (
    <div className="pointer-events-none absolute right-3 bottom-3 rounded-full bg-slate-900/80 px-3 py-1 text-xs font-medium text-white shadow">
      Saving…
    </div>
  )
}

interface ProgressThrottler {
  queue: (payload: WatchPayload) => void
  flush: (payload?: WatchPayload, options?: WatchRequestOptions) => void
  cancel: () => void
}

function createProgressThrottler(
  intervalMs: number,
  persist: (payload: WatchPayload, options?: WatchRequestOptions) => void,
): ProgressThrottler {
  let timer: number | null = null
  let pending: WatchPayload | null = null

  function clearTimer(): void {
    if (timer === null) return
    window.clearTimeout(timer)
    timer = null
  }

  return {
    queue(payload) {
      pending = payload
      if (timer !== null) return

      timer = window.setTimeout(() => {
        if (pending) {
          persist(pending)
        }
        pending = null
        timer = null
      }, intervalMs)
    },
    flush(payload, options) {
      const next = payload ?? pending
      pending = null
      clearTimer()
      if (!next) return
      persist(next, options)
    },
    cancel() {
      pending = null
      clearTimer()
    },
  }
}
