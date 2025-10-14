import ContinueWatchingShelf from './shelves/continue_watching_shelf'

interface LibraryHeroProps {
  continueWatching: LibrarySessionPayload[]
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

export default function LibraryHero({ continueWatching }: LibraryHeroProps) {
  return (
    <section className="space-y-6 px-12 py-8">
      <ContinueWatchingShelf sessions={continueWatching} />
    </section>
  )
}
