export interface WatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  completed: boolean
  lastWatchedAt?: string | null
}

interface WatchHistoryResult {
  ok: boolean
  message?: string
}

export interface WatchRequestOptions {
  keepalive?: boolean
}

export async function postWatchHistory(
  url: string,
  payload: WatchPayload,
  options: WatchRequestOptions = {},
): Promise<WatchHistoryResult> {
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": getCsrfToken(),
      },
      body: JSON.stringify({ watch: payload }),
      credentials: "same-origin",
      keepalive: options.keepalive === true,
    })

    if (!response.ok) {
      const message = await extractErrorMessage(response)
      return { ok: false, message }
    }

    return { ok: true }
  } catch (error) {
    return {
      ok: false,
      message:
        error instanceof Error ? error.message : "Unable to save progress",
    }
  }
}

function getCsrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta?.getAttribute("content") ?? ""
}

async function extractErrorMessage(response: Response): Promise<string> {
  try {
    const json = await response.json()
    if (typeof json?.error === "string") return json.error
  } catch (_) {
    // no-op; fall back to status text
  }

  return response.statusText || "Unable to save progress"
}
