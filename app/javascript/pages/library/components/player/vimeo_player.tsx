import { useCallback, useEffect, useMemo, useRef, useState } from "react"

import { postWatchHistory, type WatchPayload } from "./watch_history"

const ACTIVATION_ROOT_MARGIN = "200px"
const POSTER_SIZES = [1280, 960, 640, 320]

interface VimeoPlayerProps {
  session: LibrarySessionPayload
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

interface WritableRef<T> {
  current: T
}

type VimeoMessage =
  | { event: "ready" }
  | { event: "play" }
  | { event: "pause" }
  | { event: "timeupdate"; data: { seconds: number; duration: number } }
  | { event: "ended" }

const TRACKED_EVENTS = ["play", "pause", "timeupdate", "ended"] as const

export default function VimeoPlayer({ session }: VimeoPlayerProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const [isActivated, setIsActivated] = useState(false)
  const [shouldPlay, setShouldPlay] = useState(false)
  const hoverTimerRef = useRef<number | null>(null)
  const hasAutoplayedRef = useRef(false)

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
  }, [])

  useEffect(() => {
    return () => {
      if (hoverTimerRef.current) {
        window.clearTimeout(hoverTimerRef.current)
      }
    }
  }, [])

  const posterImage = usePosterUrl(session)

  return (
    <div
      ref={containerRef}
      className="absolute inset-0 bg-black"
      onMouseEnter={handlePointerEnter}
      onMouseLeave={handlePointerLeave}
      onFocusCapture={handlePointerEnter}
      onBlurCapture={handlePointerLeave}
    >
      {isActivated ? (
        <ActiveVimeoPlayer session={session} shouldPlay={shouldPlay} />
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
    </div>
  )
}

interface ActiveVimeoPlayerProps {
  session: LibrarySessionPayload
  shouldPlay: boolean
}

function ActiveVimeoPlayer({ session, shouldPlay }: ActiveVimeoPlayerProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null)
  const [isReady, setIsReady] = useState(false)
  const [status, setStatus] = useState<PlaybackStatus>({ state: "idle" })
  const progressRef = useRef<WatchPayload | null>(session.watch ?? null)
  const fallbackOriginRef = useRef<string>(new URL(session.playerSrc).origin)
  const vimeoOriginRef = useRef<string | null>(null)

  const watchPath = session.watchHistoryPath

  useEffect(() => {
    progressRef.current = session.watch ?? null
  }, [session.watch])

  useEffect(() => {
    fallbackOriginRef.current = new URL(session.playerSrc).origin
    vimeoOriginRef.current = null
    setIsReady(false)
  }, [session.playerSrc])

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
          void persistProgress(watchPath, next, setStatus)
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
          void persistProgress(watchPath, next, setStatus)
          break
        }
        default: {
          break
        }
      }
    },
    [watchPath],
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
  }, [handleVimeoMessage])

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
      <iframe
        ref={frameRef}
        title={session.title}
        src={session.playerSrc + "&controls=0"}
        className="absolute inset-0 size-full"
        allow="autoplay; fullscreen; picture-in-picture; clipboard-write"
        loading="lazy"
        referrerPolicy="strict-origin-when-cross-origin"
      />
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
) {
  setStatus({ state: "saving" })

  const result = await postWatchHistory(url, payload)

  if (!result.ok) {
    setStatus({
      state: "error",
      message: result.message ?? "Unable to save progress",
    })
    return
  }

  setStatus({ state: "idle" })
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
