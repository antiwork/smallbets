import type { WatchPayload, WatchRequestOptions } from "../watch_history"

export interface ProgressThrottler {
  queue: (payload: WatchPayload) => void
  flush: (payload?: WatchPayload, options?: WatchRequestOptions) => void
  cancel: () => void
}

export function createProgressThrottler(
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
        if (pending) persist(pending)
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
