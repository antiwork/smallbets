import { useMemo } from 'react'

import VimeoPlayer from '../player/vimeo_player'

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

function formatTimeRemaining(playedSeconds: number, durationSeconds?: number | null): string {
  if (!durationSeconds) return ''

  const remaining = Math.max(0, durationSeconds - playedSeconds)
  const hours = Math.floor(remaining / 3600)
  const minutes = Math.floor((remaining % 3600) / 60)

  if (hours > 0) {
    return `${hours}h ${minutes}m left`
  }
  return `${minutes}m left`
}

export default function ContinueWatchingShelf({ sessions }: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions.slice(0, 6), [sessions])

  if (items.length === 0) {
    return null
  }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold text-white">Continue Watching</h2>

      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
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
    <a href={`#session-${session.id}`} className="group flex w-80 shrink-0 flex-col gap-2">
      <div className="relative w-full overflow-hidden rounded-md" style={{ paddingBottom: `${session.padding}%` }}>
        <VimeoPlayer session={session} />
      </div>

      <div className="flex flex-col">
        <h3 className="text-sm font-medium text-white">{session.title}</h3>
        {timeRemaining && <p className="text-xs text-gray-400">{timeRemaining}</p>}
      </div>
    </a>
  )
}
