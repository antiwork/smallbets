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
  const primaryCategory = session.categories[0]

  return (
    <article
      id={`session-${session.id}`}
      className="flex h-full flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition hover:shadow"
    >
      <div className="relative w-full overflow-hidden" style={{ paddingBottom: `${session.padding}%` }}>
        <VimeoPlayer session={session} />
      </div>

      <div className="flex flex-1 flex-col gap-4 p-4">
        <header className="space-y-2">
          {primaryCategory && (
            <span className="inline-flex items-center rounded-full bg-slate-900/5 px-2.5 py-0.5 text-xs font-medium tracking-wide text-slate-700">
              {primaryCategory.name}
            </span>
          )}
          <h3 className="text-lg font-semibold text-slate-900">{session.title}</h3>
        </header>

        <p className="text-sm text-slate-600 line-clamp-3">{session.description}</p>

        <footer className="mt-auto flex items-center justify-between text-sm text-slate-500">
          <DownloadButton href={session.downloadPath} />
          <WatchMeta watch={session.watch} />
        </footer>
      </div>
    </article>
  )
}

function formatRelative(isoDate: string) {
  const date = new Date(isoDate)
  const now = Date.now()
  const diff = now - date.getTime()

  const minutes = Math.round(diff / (1000 * 60))
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes} min ago`

  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours} hr${hours > 1 ? 's' : ''} ago`

  const days = Math.round(hours / 24)
  if (days < 7) return `${days} day${days > 1 ? 's' : ''} ago`

  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

function DownloadButton({ href }: { href: string }) {
  return (
    <a
      href={href}
      className="inline-flex items-center gap-2 rounded-full bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow hover:bg-slate-800"
    >
      Download
    </a>
  )
}

function WatchMeta({ watch }: { watch?: LibraryWatchPayload | null }) {
  if (!watch?.lastWatchedAt) return <span />

  return (
    <time dateTime={watch.lastWatchedAt} className="text-xs text-slate-500">
      Last watched {formatRelative(watch.lastWatchedAt)}
    </time>
  )
}
