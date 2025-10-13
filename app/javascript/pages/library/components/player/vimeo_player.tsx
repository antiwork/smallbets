import { useCallback, useEffect, useRef, useState } from 'react'

import { postWatchHistory, type WatchPayload } from './watch_history'

interface VimeoPlayerProps {
  session: LibrarySessionPayload
}

interface LibrarySessionPayload {
  id: number
  title: string
  description: string
  padding: number
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

type VimeoMessage =
  | { event: 'ready' }
  | { event: 'play' }
  | { event: 'pause' }
  | { event: 'timeupdate'; data: { seconds: number; duration: number } }
  | { event: 'ended' }

const TRACKED_EVENTS = ['play', 'pause', 'timeupdate', 'ended'] as const

interface WritableRef<T> {
  current: T
}

export default function VimeoPlayer({ session }: VimeoPlayerProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null)
  const [isReady, setIsReady] = useState(false)
  const [status, setStatus] = useState<PlaybackStatus>({ state: 'idle' })
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
      setStatus((current) => (current.state === 'error' ? current : { state: 'idle' }))

      switch (message.event) {
        case 'ready': {
          subscribeToEvents(frameRef.current, vimeoOriginRef, fallbackOriginRef.current)
          setIsReady(true)
          break
        }
        case 'timeupdate': {
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
        case 'ended': {
          const duration = progressRef.current?.durationSeconds ?? progressRef.current?.playedSeconds ?? 0
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
      if (!isVimeoEvent(event, frame, vimeoOriginRef, fallbackOriginRef.current)) return

      const payload = normalizeData(event.data)
      if (!payload) return

      handleVimeoMessage(payload)
    }

    window.addEventListener('message', handleMessage)
    postToVimeo(frame, vimeoOriginRef, { method: 'ping' }, {
      allowWildcard: true,
      fallbackOrigin: fallbackOriginRef.current,
    })

    return () => {
      window.removeEventListener('message', handleMessage)
    }
  }, [handleVimeoMessage])

  useEffect(() => {
    const resumeAt = progressRef.current?.playedSeconds
    if (!isReady || resumeAt == null || !frameRef.current) return

    postToVimeo(frameRef.current, vimeoOriginRef, {
      method: 'setCurrentTime',
      value: resumeAt,
    })
  }, [isReady])

  return (
    <div className="absolute inset-0">
      <iframe
        ref={frameRef}
        title={session.title}
        src={session.playerSrc}
        className="size-full"
        allow="autoplay; fullscreen; picture-in-picture; clipboard-write"
        allowFullScreen
        loading="lazy"
        referrerPolicy="strict-origin-when-cross-origin"
      />
      <StatusIndicator status={status} />
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
    if (typeof data === 'string') {
      return JSON.parse(data) as VimeoMessage
    }

    if (typeof data === 'object' && data !== null) {
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

  frame.contentWindow.postMessage(payload, options.allowWildcard ? '*' : targetOrigin)
}

function resolveOrigin(originRef: WritableRef<string | null>, fallbackOrigin?: string): string | null {
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
        method: 'addEventListener',
        value: event,
      },
      { fallbackOrigin },
    )
  })
}

type PlaybackStatus =
  | { state: 'idle' }
  | { state: 'saving' }
  | { state: 'error'; message: string }

async function persistProgress(url: string, payload: LibraryWatchPayload, setStatus: (status: PlaybackStatus) => void) {
  setStatus({ state: 'saving' })

  const result = await postWatchHistory(url, payload)

  if (!result.ok) {
    setStatus({ state: 'error', message: result.message ?? 'Unable to save progress' })
    return
  }

  setStatus({ state: 'idle' })
}

function StatusIndicator({ status }: { status: PlaybackStatus }) {
  if (status.state === 'idle') return null

  if (status.state === 'error') {
    return (
      <div className="pointer-events-none absolute bottom-3 right-3 rounded-xl bg-red-900/90 px-3 py-2 text-xs font-medium text-white shadow">
        {status.message}
      </div>
    )
  }

  return (
    <div className="pointer-events-none absolute bottom-3 right-3 rounded-full bg-slate-900/80 px-3 py-1 text-xs font-medium text-white shadow">
      Saving…
    </div>
  )
}
