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
  postWatchHistory,
  type WatchPayload,
  type WatchRequestOptions,
} from "./watch_history"

const ACTIVATION_ROOT_MARGIN = "200px"
const POSTER_SIZES = [1280, 960, 640, 320]

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
  thumbnailUrl?: string | null
  vimeoId: string
  vimeoHash?: string
  playerSrc: string
  watchHistoryPath: string
  watch?: LibraryWatchPayload | null
}

interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

interface FullscreenDocument extends Document {
  webkitFullscreenElement?: Element | null
}

interface FullscreenElement extends HTMLElement {
  webkitRequestFullscreen?: () => Promise<void> | void
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
      }, 1500)
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

    useEffect(() => {
      const doc = document as FullscreenDocument

      const handleFullscreenChange = () => {
        const fullscreenElement =
          doc.fullscreenElement ?? doc.webkitFullscreenElement ?? null
        const container = containerRef.current
        if (!fullscreenElement || !container) {
          setShowControls(false)
          return
        }
        setShowControls(
          fullscreenElement === container ||
            container.contains(fullscreenElement),
        )
      }

      document.addEventListener("fullscreenchange", handleFullscreenChange)
      document.addEventListener(
        "webkitfullscreenchange",
        handleFullscreenChange,
      )

      return () => {
        document.removeEventListener("fullscreenchange", handleFullscreenChange)
        document.removeEventListener(
          "webkitfullscreenchange",
          handleFullscreenChange,
        )
      }
    }, [])

    const requestFullscreen = useCallback(() => {
      const element = containerRef.current as FullscreenElement | null
      if (!element) return

      if (element.requestFullscreen) {
        void element.requestFullscreen().catch(() => undefined)
        return
      }

      if (element.webkitRequestFullscreen) {
        element.webkitRequestFullscreen()
      }
    }, [])

    const enterFullscreen = useCallback(() => {
      if (!isActivated) {
        setIsActivated(true)
        setShouldPlay(true)
        hasAutoplayedRef.current = true
      }
      requestFullscreen()
    }, [isActivated, requestFullscreen])

    useImperativeHandle(ref, () => ({
      enterFullscreen,
      startPreview: handlePointerEnter,
      stopPreview: handlePointerLeave,
    }))

    const posterImage = usePosterUrl(session)

    return (
      <div
        ref={containerRef}
        className="vimeo-fullscreen absolute inset-0 cursor-pointer bg-black"
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
            className="group relative flex size-full items-center justify-center overflow-hidden bg-black text-white"
          >
            {posterImage ? (
              <img
                src={posterImage}
                alt={session.title}
                decoding="async"
                loading="lazy"
                className="absolute inset-0 size-full object-contain"
              />
            ) : (
              <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-slate-900 to-slate-800" />
            )}
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

  const watchPath = session.watchHistoryPath

  const markHistoryPersisted = useCallback(() => {
    hasPersistedHistoryRef.current = true
  }, [])

  const throttler = useMemo(
    () =>
      createProgressThrottler(10_000, (payload, options) => {
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
    if (!isReady || !frameRef.current) return

    postToVimeo(frameRef.current, vimeoOriginRef, {
      method: shouldPlay ? "play" : "pause",
    })
  }, [isReady, shouldPlay])

  return (
    <div className="relative size-full bg-black">
      <div
        className={
          isFullscreen
            ? "absolute inset-0 flex items-center justify-center"
            : "absolute inset-0"
        }
      >
        <iframe
          ref={frameRef}
          title={session.title}
          src={playerSrc}
          className={
            isFullscreen
              ? "vimeo-embed h-auto max-h-[100vh] w-[100vw]"
              : "vimeo-embed size-full"
          }
          style={isFullscreen ? { aspectRatio: "16 / 9" } : undefined}
          allow="autoplay; picture-in-picture; clipboard-write"
          loading="lazy"
          referrerPolicy="strict-origin-when-cross-origin"
        />
      </div>
      <StatusIndicator status={status} />
    </div>
  )
}

function usePosterUrl(session: LibrarySessionPayload): string | undefined {
  return useMemo(() => {
    if (session.thumbnailUrl) return session.thumbnailUrl
    try {
      const url = new URL(session.playerSrc)
      const idParts = url.pathname.split("/").filter(Boolean)
      const last = idParts[idParts.length - 1]
      if (!last) return undefined
      return `https://i.vimeocdn.com/video/${last}_${POSTER_SIZES[2]}.webp`
    } catch (_error) {
      return undefined
    }
  }, [session.playerSrc, session.thumbnailUrl])
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
