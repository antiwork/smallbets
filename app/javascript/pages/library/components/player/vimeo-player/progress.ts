import {
  postWatchHistory,
  type WatchPayload,
  type WatchRequestOptions,
} from "../watch_history"
import type { PlaybackStatus } from "./types"

export async function persistProgress(
  url: string,
  payload: WatchPayload,
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
    console.error(
      "[Library] Failed to save watch progress",
      result.message ?? "Unable to save progress",
      { payload },
    )
    return false
  }
  setStatus({ state: "idle" })
  return true
}
