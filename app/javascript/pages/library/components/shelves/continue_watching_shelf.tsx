import { useMemo } from 'react'

import { cn } from '../../../../lib/utils'

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

export default function ContinueWatchingShelf({ sessions }: ContinueWatchingShelfProps) {
  const items = useMemo(() => sessions.slice(0, 6), [sessions])

  if (items.length === 0) {
    return null
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-200/80">
          Continue watching
        </h2>
      </div>

      <div className="flex snap-x snap-mandatory gap-4 overflow-x-auto pb-1">
        {items.map((session) => (
          <ContinueWatchingCard key={session.id} session={session} />
        ))}
      </div>
    </div>
  )
}

function ContinueWatchingCard({ session }: { session: LibrarySessionPayload }) {
  const progress = session.watch?.playedSeconds ?? 0
  const duration = session.watch?.durationSeconds ?? 0
  const ratio = duration > 0 ? Math.min(progress / duration, 1) : 0

  return (
    <a
      href={`#session-${session.id}`}
      className="group relative flex w-64 shrink-0 snap-start overflow-hidden rounded-2xl bg-white/5"
    >
      <div className="absolute inset-0" />
      <div className="relative flex flex-col gap-3 p-4">
        <span className="inline-flex items-center gap-2 text-xs font-medium text-slate-200/80">
          <span className="inline-flex size-6 items-center justify-center rounded-full bg-white/10 align-middle">
            <svg viewBox="0 0 24 24" className="size-3.5" fill="currentColor" aria-hidden>
              <path d="M8 5v14l11-7z" />
            </svg>
          </span>
          {session.categories[0]?.name ?? 'Class'}
        </span>
        <div className="space-y-1">
          <h3 className="text-base font-semibold text-white/90">{session.title}</h3>
          <p className="text-xs text-white/70 line-clamp-2">{session.description}</p>
        </div>
        <Progress value={ratio} />
      </div>
    </a>
  )
}

function Progress({ value }: { value: number }) {
  return (
    <div className="h-1.5 rounded-full bg-white/10">
      <div
        className={cn('h-1.5 rounded-full bg-white transition-all duration-300', value === 1 && 'bg-emerald-400')}
        style={{ width: `${Math.max(value, 0) * 100}%` }}
      />
    </div>
  )
}
