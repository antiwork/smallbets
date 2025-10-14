import VimeoPlayer from './player/vimeo_player'

interface VideoCardProps {
  session: LibrarySessionPayload
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

export default function VideoCard({ session }: VideoCardProps) {
  return (
    <article id={`session-${session.id}`} className="group flex w-80 shrink-0 flex-col gap-2">
      <div className="relative w-full overflow-hidden rounded-md" style={{ paddingBottom: `${session.padding}%` }}>
        <VimeoPlayer session={session} />
      </div>

      <h3 className="text-sm font-medium text-white">{session.title}</h3>
    </article>
  )
}
