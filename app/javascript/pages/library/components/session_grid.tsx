import type { LibrarySessionPayload } from "../types"
import { SessionsShelfRow } from "./shelves/sessions_shelf_row"

interface SessionGridProps {
  sessions: LibrarySessionPayload[]
  backIcon?: string
}

export default function SessionGrid({ sessions, backIcon }: SessionGridProps) {
  return <SessionsShelfRow sessions={sessions} backIcon={backIcon} />
}
