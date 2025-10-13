import { Head } from '@inertiajs/react'
import { useEffect, useMemo, useState } from 'react'

import { cn } from '../../lib/utils'

import LibraryHero from './components/library_hero'
import SectionHeader from './components/layout/section_header'
import SessionGrid from './components/session_grid'

interface LibraryPageProps {
  continueWatching: LibrarySessionPayload[]
  sections: LibrarySectionPayload[]
  layout?: LayoutPayload
}

interface LibrarySectionPayload {
  id: number
  slug: string
  title: string
  creator: string
  categories: LibraryCategoryPayload[]
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

interface LayoutPayload {
  pageTitle?: string
  bodyClass?: string
  nav?: string
  sidebar?: string
}

export default function LibraryIndex({ continueWatching, sections, layout }: LibraryPageProps) {
  useEffect(() => {
    if (!layout) return

    if (layout.bodyClass) {
      document.body.className = layout.bodyClass
    }

    if (layout.nav) {
      const nav = document.getElementById('nav')
      if (nav) nav.innerHTML = layout.nav
    }

    if (layout.sidebar) {
      const sidebar = document.getElementById('sidebar')
      if (sidebar) sidebar.innerHTML = layout.sidebar
    }
  }, [layout?.bodyClass, layout?.nav, layout?.sidebar])

  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)

  const categories = useMemo(() => {
    const all = sections.flatMap((section) => section.categories)
    const uniqueSlugs = new Map(all.map((category) => [category.slug, category]))
    return Array.from(uniqueSlugs.values())
  }, [sections])

  const filteredSections = useMemo(() => {
    if (!selectedCategory) return sections

    return sections
      .map((section) => {
        const filteredSessions = section.sessions.filter((session) =>
          session.categories.some((category) => category.slug === selectedCategory),
        )

        return { ...section, sessions: filteredSessions }
      })
      .filter((section) => section.sessions.length > 0)
  }, [sections, selectedCategory])

  const showFilters = categories.length > 1

  return (
    <div className="library">
      <div className="space-y-12 pb-16">
        <Head title="Library" />

        <LibraryHero continueWatching={continueWatching} />

        {showFilters && (
          <section className="mx-auto flex max-w-5xl flex-wrap gap-2 px-4">
            <button
              type="button"
              onClick={() => setSelectedCategory(null)}
              className={cn(
                'rounded-full border border-slate-200 px-3 py-1 text-sm font-medium transition',
                selectedCategory === null
                  ? 'bg-slate-900 text-white shadow'
                  : 'bg-white text-slate-700 hover:bg-slate-50',
              )}
            >
              All
            </button>

            {categories.map((category) => {
              const isActive = selectedCategory === category.slug

              return (
                <button
                  key={category.slug}
                  type="button"
                  onClick={() => setSelectedCategory(isActive ? null : category.slug)}
                  className={cn(
                    'rounded-full border border-slate-200 px-3 py-1 text-sm font-medium transition',
                    isActive ? 'bg-slate-900 text-white shadow' : 'bg-white text-slate-700 hover:bg-slate-50',
                  )}
                >
                  {category.name}
                </button>
              )
            })}
          </section>
        )}

        <section className="space-y-16">
          {filteredSections.length === 0 ? (
            <EmptyState onReset={() => setSelectedCategory(null)} />
          ) : (
            filteredSections.map((section) => (
              <div key={section.id} className="space-y-6">
                <SectionHeader eyebrow={section.creator} title={section.title} />
                <SessionGrid sessions={section.sessions} />
              </div>
            ))
          )}
        </section>
      </div>
    </div>
  )
}

function EmptyState({ onReset }: { onReset: () => void }) {
  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-4 rounded-2xl border border-dashed border-slate-200 bg-white px-6 py-10 text-center shadow-sm">
      <div className="flex size-12 items-center justify-center rounded-full bg-slate-900/5 text-slate-900">
        <svg viewBox="0 0 24 24" className="size-6" fill="none" stroke="currentColor" strokeWidth="1.5">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M3 7h18M3 12h18M3 17h18"
          />
        </svg>
      </div>
      <div className="space-y-1">
        <h3 className="text-lg font-semibold text-slate-900">No sessions match that filter</h3>
        <p className="text-sm text-slate-600">Try another category or reset the filters to see everything.</p>
      </div>
      <button
        type="button"
        onClick={onReset}
        className="rounded-full bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow hover:bg-slate-800"
      >
        Reset filters
      </button>
    </div>
  )
}
