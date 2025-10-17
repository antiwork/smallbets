import { useMemo } from "react"

import type { LibrarySessionPayload } from "../../types"
import { SessionsShelfRow } from "./sessions_shelf_row"

interface ContinueWatchingShelfProps {
  sessions: LibrarySessionPayload[]
  backIcon?: string
}

export default function ContinueWatchingShelf({
  sessions,
  backIcon,
}: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions, [sessions])

  return (
    <SessionsShelfRow
      sessions={items}
      backIcon={backIcon}
      title="Continue Watching"
      showProgress
      persistPreview
    />
  )
}
