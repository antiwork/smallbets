import { useMemo } from "react"

import VideoCard from "../video_card"

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
  creator: string
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

export default function ContinueWatchingShelf({
  sessions,
}: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions, [sessions])

  if (items.length === 0) {
    return null
  }

  return (
    <div className="flex flex-col gap-[1vw]">
      <h2 className="pl-1 text-xl leading-tight font-medium tracking-wider text-white capitalize select-none">
        Continue Watching
      </h2>

      <div className="scrollbar-hide flex gap-[0.4vw] overflow-x-auto overflow-y-visible pr-0 pb-[0.4vw] [--shelf-card-w:calc((100%_-_var(--shelf-gap)_*_(var(--shelf-items)))/(var(--shelf-items)_+_var(--shelf-peek)))] [--shelf-gap:0.4vw] [--shelf-items:2] [--shelf-peek:0.25] md:[--shelf-items:3] lg:[--shelf-items:4] xl:[--shelf-items:5] 2xl:[--shelf-items:6]">
        {items.map((session) => (
          <ContinueWatchingCard key={session.id} session={session} />
        ))}
      </div>
    </div>
  )
}

function ContinueWatchingCard({ session }: { session: LibrarySessionPayload }) {
  return <VideoCard session={session} showProgress />
}
