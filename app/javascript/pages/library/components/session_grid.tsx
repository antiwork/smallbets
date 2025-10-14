import VideoCard from "./video_card"

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
    <div className="relative">
      <div
        className="scrollbar-hide flex overflow-x-auto overflow-y-visible"
        style={{
          gap: "0.8vw",
          paddingBottom: "0.4vw",
          paddingRight: "4vw",
        }}
      >
        {sessions.map((session) => (
          <VideoCard key={session.id} session={session} />
        ))}
      </div>
    </div>
  )
}
