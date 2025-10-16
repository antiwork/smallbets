const EVENT_NAME = "sb:autoplay-audio:change"

let autoplaySoundEnabled = false

function getWindow(): Window | null {
  if (typeof window === "undefined") return null
  return window
}

function dispatchChange(windowRef: Window | null, enabled: boolean): void {
  if (!windowRef) return
  const detail = { enabled }
  windowRef.dispatchEvent(new CustomEvent(EVENT_NAME, { detail }))
}

export interface AutoplayAudioPayload {
  enabled: boolean
}

export function getAutoplaySoundEnabled(): boolean {
  return autoplaySoundEnabled
}

export function setAutoplaySoundEnabled(enabled: boolean): void {
  if (enabled === autoplaySoundEnabled) return
  autoplaySoundEnabled = enabled
  dispatchChange(getWindow(), autoplaySoundEnabled)
}

type AutoplayAudioListener = (enabled: boolean) => void

export function subscribeToAutoplaySound(
  listener: AutoplayAudioListener,
): () => void {
  const windowRef = getWindow()
  if (!windowRef) {
    return () => undefined
  }

  const handler = (event: Event) => {
    if (!(event instanceof CustomEvent)) return
    const payload = event.detail as AutoplayAudioPayload | undefined
    if (!payload) return
    listener(payload.enabled)
  }

  windowRef.addEventListener(EVENT_NAME, handler)

  return () => {
    windowRef.removeEventListener(EVENT_NAME, handler)
  }
}
