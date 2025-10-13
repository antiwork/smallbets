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
    <section className="relative overflow-hidden">
      <div className="relative mx-auto flex max-w-6xl flex-col gap-10 px-4 py-12 text-white sm:px-6 lg:px-8">
        <ContinueWatchingShelf sessions={continueWatching} />
      </div>
    </section>
  )
}
