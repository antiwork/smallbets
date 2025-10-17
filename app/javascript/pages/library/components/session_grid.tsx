// No longer requires player refs; navigation goes to watch page
import VideoCard from "./video_card"

interface SessionGridProps {
  sessions: LibrarySessionPayload[]
  backIcon?: string
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

export default function SessionGrid({ sessions, backIcon }: SessionGridProps) {
  if (sessions.length === 0) {
    return null
  }

  return (
    <div className="relative">
      <div className="scrollbar-hide flex gap-[0.8vw] overflow-x-auto overflow-y-visible pr-0 pb-[0.4vw] [--shelf-card-w:calc((100%_-_var(--shelf-gap)_*_(var(--shelf-items)))/(var(--shelf-items)_+_var(--shelf-peek)))] [--shelf-gap:0.8vw] [--shelf-items:2] [--shelf-peek:0.25] md:[--shelf-items:3] lg:[--shelf-items:4] xl:[--shelf-items:5] 2xl:[--shelf-items:6]">
        {sessions.map((session) => (
          <VideoCard key={session.id} session={session} backIcon={backIcon} />
        ))}
      </div>
    </div>
  )
}
