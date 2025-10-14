import { Head } from '@inertiajs/react'
import { useEffect, useMemo } from 'react'

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

interface CategoryGroup {
  category: LibraryCategoryPayload
  sessions: LibrarySessionPayload[]
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

  const categoryGroups = useMemo(() => {
    const categoryMap = new Map<string, CategoryGroup>()

    sections.forEach((section) => {
      section.sessions.forEach((session) => {
        session.categories.forEach((category) => {
          if (!categoryMap.has(category.slug)) {
            categoryMap.set(category.slug, {
              category,
              sessions: [],
            })
          }
          const group = categoryMap.get(category.slug)!
          if (!group.sessions.some((s) => s.id === session.id)) {
            group.sessions.push(session)
          }
        })
      })
    })

    return Array.from(categoryMap.values())
  }, [sections])

  return (
    <div className="library min-h-screen bg-black">
      <div className="space-y-12 pb-16">
        <Head title="Library" />

        <LibraryHero continueWatching={continueWatching} />

        <section className="space-y-12 px-12">
          {categoryGroups.map((group) => (
            <div key={group.category.slug} className="space-y-6">
              <SectionHeader eyebrow="" title={group.category.name} />
              <SessionGrid sessions={group.sessions} />
            </div>
          ))}
        </section>
      </div>
    </div>
  )
}
