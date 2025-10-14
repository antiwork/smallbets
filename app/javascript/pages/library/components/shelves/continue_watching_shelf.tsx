import { useMemo } from "react"

import VimeoPlayer from "../player/vimeo_player"

interface ContinueWatchingShelfProps {
  sessions: LibrarySessionPayload[]
}

interface LibrarySessionPayload {
  id: number
  title: string
  description: string
  categories: LibraryCategoryPayload[]
  padding: number
  vimeoId: string
  vimeoHash?: string
  playerSrc: string
  downloadPath: string
  position: number
  watchHistoryPath: string
  watch?: LibraryWatchPayload | null
}

interface LibraryCategoryPayload {
  id: number
  name: string
  slug: string
}

interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

function formatTimeRemaining(
  playedSeconds: number,
  durationSeconds?: number | null,
): string {
  if (!durationSeconds) return ""

  const remaining = Math.max(0, durationSeconds - playedSeconds)
  const hours = Math.floor(remaining / 3600)
  const minutes = Math.floor((remaining % 3600) / 60)

  if (hours > 0) {
    return `${hours}h ${minutes}m left`
  }
  return `${minutes}m left`
}

export default function ContinueWatchingShelf({
  sessions,
}: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions.slice(0, 6), [sessions])

  if (items.length === 0) {
    return null
  }

  return (
    <div className="flex flex-col gap-6">
      <h2 className="text-xl font-medium tracking-wider capitalize">
        Continue Watching
      </h2>

      <div className="scrollbar-hide flex gap-2 overflow-x-auto pb-2">
        {items.map((session) => (
          <ContinueWatchingCard key={session.id} session={session} />
        ))}
      </div>
    </div>
  )
}

function ContinueWatchingCard({ session }: { session: LibrarySessionPayload }) {
  const progress = session.watch?.playedSeconds ?? 0
  const duration = session.watch?.durationSeconds ?? 0
  const timeRemaining = formatTimeRemaining(progress, duration)

  return (
    <a
      href={`#session-${session.id}`}
      className="group flex w-80 shrink-0 flex-col gap-2"
    >
      <div className="relative aspect-video w-full overflow-hidden rounded-md">
        <VimeoPlayer session={session} />
      </div>

      <div className="flex flex-col">
        <h3 className="text-sm font-medium text-white">{session.title}</h3>
        {timeRemaining && (
          <p className="text-xs text-gray-400">{timeRemaining}</p>
        )}
      </div>
    </a>
  )
}
