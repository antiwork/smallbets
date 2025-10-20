import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../types"
import { SessionsShelfRow } from "./shelves/sessions_shelf_row"

interface SessionGridProps {
  sessions: LibrarySessionPayload[]
  backIcon?: string
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

export default function SessionGrid({
  sessions,
  backIcon,
  thumbnails,
}: SessionGridProps) {
  return (
    <SessionsShelfRow
      sessions={sessions}
      backIcon={backIcon}
      thumbnails={thumbnails}
    />
  )
}
