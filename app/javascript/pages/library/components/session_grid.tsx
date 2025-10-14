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
    return null
  }

  return (
    <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
      {sessions.map((session) => (
        <VideoCard key={session.id} session={session} />
      ))}
    </div>
  )
}
