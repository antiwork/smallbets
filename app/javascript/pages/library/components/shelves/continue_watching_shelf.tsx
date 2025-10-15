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
  const items = useMemo(() => sessions.slice(0, 6), [sessions])

  if (items.length === 0) {
    return null
  }

  return (
    <div className="flex flex-col gap-[1.5vw]">
      <h2 className="text-[1.4vw] leading-[1.25vw] font-medium tracking-wider text-white capitalize">
        Continue Watching
      </h2>

      <div className="scrollbar-hide flex gap-[0.4vw] overflow-x-auto overflow-y-visible pr-[4vw] pb-[0.4vw]">
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
