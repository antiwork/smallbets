import { Head } from "@inertiajs/react"
import { useEffect, useMemo } from "react"

import LibraryHero from "./components/library_hero"
import SectionHeader from "./components/layout/section_header"
import SessionGrid from "./components/session_grid"
import type {
  LibrarySessionPayload,
  LibraryCategoryPayload,
  LibraryLayoutPayload,
} from "./types"

interface LibraryPageProps {
  continueWatching: LibrarySessionPayload[]
  sections: LibrarySectionPayload[]
  layout?: LayoutPayload
  initialSessionId?: number | null
  assets?: {
    backIcon?: string
    downloadIcon?: string
  }
}

interface LibrarySectionPayload {
  id: number
  slug: string
  title: string
  creator: string
  categories: LibraryCategoryPayload[]
  sessions: LibrarySessionPayload[]
}

type LayoutPayload = LibraryLayoutPayload

interface CategoryGroup {
  category: LibraryCategoryPayload
  sessions: LibrarySessionPayload[]
}

export default function LibraryIndex({
  continueWatching,
  sections,
  layout,
  assets,
}: LibraryPageProps) {
  useEffect(() => {
    if (!layout) return

    if (layout.bodyClass) {
      document.body.className = layout.bodyClass
    }

    if (layout.nav) {
      const nav = document.getElementById("nav")
      if (nav) nav.innerHTML = layout.nav
    }

    if (layout.sidebar) {
      const sidebar = document.getElementById("sidebar")
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
    <div className="bg-background mt-[3vw] min-h-screen py-12 min-[120ch]:pl-[5vw]">
      <div className="pb-16">
        <Head title="Library" />
        <h1 className="sr-only">Library</h1>

        <div className="flex flex-col gap-10 pt-12 sm:gap-[3vw]">
          <LibraryHero
            continueWatching={continueWatching}
            backIcon={assets?.backIcon}
          />

          <div className="flex flex-col gap-10 pl-3 sm:gap-[3vw]">
            {categoryGroups.map((group) => {
              const headingId = `category-${group.category.slug}`
              return (
                <section
                  className="flex flex-col gap-[1vw]"
                  key={group.category.slug}
                  aria-labelledby={headingId}
                >
                  <SectionHeader id={headingId} title={group.category.name} />
                  <SessionGrid
                    sessions={group.sessions}
                    backIcon={assets?.backIcon}
                  />
                </section>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
