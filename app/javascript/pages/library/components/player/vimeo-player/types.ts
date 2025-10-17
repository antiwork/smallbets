export interface WritableRef<T> {
  current: T
}

export type VimeoMessage =
  | { event: "ready" }
  | { event: "play" }
  | { event: "pause"; data?: PlaybackMetrics }
  | { event: "seeked"; data: PlaybackMetrics }
  | { event: "timeupdate"; data: { seconds: number; duration: number } }
  | { event: "ended" }

export interface PlaybackMetrics {
  seconds: number
  duration: number
}

export type PlaybackStatus =
  | { state: "idle" }
  | { state: "saving" }
  | { state: "error"; message: string }

export interface PostOptions {
  allowWildcard?: boolean
  fallbackOrigin?: string
}

export interface VimeoPlayerHandle {
  enterFullscreen: () => void
  startPreview: () => void
  stopPreview: () => void
  getCurrentWatch: () => import("../watch_history").WatchPayload | null
}

export interface VimeoEmbedHandle {
  flushKeepalive: () => void
  getCurrentWatch: () => import("../watch_history").WatchPayload | null
}
