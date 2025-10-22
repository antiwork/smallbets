import { useMemo } from "react"

import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"
import { SessionsShelfRow } from "./sessions_shelf_row"

interface ContinueWatchingShelfProps {
  sessions: LibrarySessionPayload[]
  backIcon?: string
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

export default function ContinueWatchingShelf({
  sessions,
  backIcon,
  thumbnails,
}: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions, [sessions])

  return (
    <SessionsShelfRow
      id="continue-watching"
      sessions={items}
      backIcon={backIcon}
      title="Continue Watching"
      showProgress
      persistPreview
      thumbnails={thumbnails}
    />
  )
}
