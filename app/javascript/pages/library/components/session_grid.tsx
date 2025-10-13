import VideoCard from './video_card'

interface SessionGridProps {
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

export default function SessionGrid({ sessions }: SessionGridProps) {
  if (sessions.length === 0) {
    return (
      <p className="mx-auto max-w-5xl rounded-lg border border-dashed border-slate-200 bg-white px-4 py-8 text-center text-sm text-slate-600 shadow-sm">
        No sessions yet. Check back soon!
      </p>
    )
  }

  return (
    <div className="mx-auto grid max-w-6xl gap-6 px-4 sm:grid-cols-2 lg:grid-cols-3">
      {sessions.map((session) => (
        <VideoCard key={session.id} session={session} />
      ))}
    </div>
  )
}
