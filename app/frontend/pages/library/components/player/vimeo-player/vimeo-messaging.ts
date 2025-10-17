import type { PostOptions, VimeoMessage, WritableRef } from "./types"

export function isVimeoEvent(
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

export function normalizeData(data: unknown): VimeoMessage | null {
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

export function postToVimeo(
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

export function resolveOrigin(
  originRef: WritableRef<string | null>,
  fallbackOrigin?: string,
): string | null {
  if (originRef.current) return originRef.current
  if (fallbackOrigin) return fallbackOrigin
  return null
}

const TRACKED_EVENTS = [
  "play",
  "pause",
  "timeupdate",
  "seeked",
  "ended",
] as const

export function subscribeToEvents(
  frame: HTMLIFrameElement | null,
  originRef: WritableRef<string | null>,
  fallbackOrigin: string,
) {
  if (!frame?.contentWindow) return
  TRACKED_EVENTS.forEach((event) => {
    postToVimeo(
      frame,
      originRef,
      { method: "addEventListener", value: event },
      { fallbackOrigin },
    )
  })
}
