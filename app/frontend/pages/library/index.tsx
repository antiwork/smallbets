import { Head } from "@inertiajs/react"
import { useEffect, useMemo, useState } from "react"

import FeaturedCarousel from "./components/featured-carousel"
import LibraryHero from "./components/library_hero"
import SectionHeader from "./components/layout/section_header"
import SessionGrid from "./components/session_grid"
import type {
  LibrarySessionPayload,
  LibraryCategoryPayload,
  LibraryLayoutPayload,
  VimeoThumbnailPayload,
} from "./types"

interface LibraryPageProps {
  continueWatching: LibrarySessionPayload[]
  featuredSessions: LibrarySessionPayload[]
  sections: LibrarySectionPayload[]
  layout?: LayoutPayload
  initialSessionId?: number | null
  assets?: {
    backIcon?: string
    downloadIcon?: string
  }
  initialThumbnails?: Record<string, VimeoThumbnailPayload>
  featuredHeroImages?: Record<string, string>
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
  featuredSessions,
  sections,
  layout,
  assets,
  initialThumbnails,
  featuredHeroImages,
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

  const [thumbnails, setThumbnails] = useState<
    Record<string, VimeoThumbnailPayload>
  >(initialThumbnails ?? {})

  useEffect(() => {
    const allIds = Array.from(
      new Set([
        ...sections.flatMap((section) =>
          section.sessions.map((session) => session.vimeoId),
        ),
        ...featuredSessions.map((session) => session.vimeoId),
        ...continueWatching.map((s) => s.vimeoId),
      ]),
    )
      .filter(Boolean)
      .map(String)

    if (allIds.length === 0) return

    // Above-the-fold priority: featured + continue watching + first shelf
    const prioritySet = new Set<string>([
      ...featuredSessions
        .map((s) => s.vimeoId)
        .filter(Boolean)
        .map(String),
      ...continueWatching
        .map((s) => s.vimeoId)
        .filter(Boolean)
        .map(String),
      ...(sections[0]?.sessions ?? [])
        .map((s) => s.vimeoId)
        .filter(Boolean)
        .map(String),
    ])
    const priorityIds = Array.from(prioritySet)
    const restIds = allIds.filter((id) => !prioritySet.has(String(id)))

    const controller = new AbortController()

    const merge = (partial: Record<string, VimeoThumbnailPayload>) => {
      if (!partial || Object.keys(partial).length === 0) return
      setThumbnails((prev) => ({ ...prev, ...partial }))
    }

    const fetchBatch = async (ids: string[]) => {
      if (ids.length === 0) return
      try {
        const params = new URLSearchParams()
        params.set("ids", Array.from(new Set(ids)).sort().join(","))
        const url = `/api/videos/thumbnails?${params.toString()}`
        const response = await fetch(url, {
          headers: { Accept: "application/json" },
          signal: controller.signal,
          credentials: "same-origin",
        })
        if (!response.ok) return
        const json = (await response.json()) as Record<
          string,
          VimeoThumbnailPayload
        >
        merge(json)
      } catch (error) {
        if ((error as Error).name === "AbortError") return
        console.warn("Failed to load Vimeo thumbnails", error)
      }
    }

    // Phase A: priority first
    void fetchBatch(priorityIds)

    // Phase B: remaining when idle
    const scheduleIdle = (cb: () => void) => {
      const ric = (
        window as unknown as {
          requestIdleCallback?: (
            fn: () => void,
            opts?: { timeout?: number },
          ) => number
        }
      ).requestIdleCallback
      if (typeof ric === "function") ric(cb, { timeout: 1500 })
      else setTimeout(cb, 300)
    }

    scheduleIdle(() => {
      void fetchBatch(restIds)
    })

    return () => {
      controller.abort()
    }
  }, [sections, continueWatching])

  return (
    <div className="bg-background mt-[3vw] min-h-screen py-12">
      <div className="pb-16">
        <Head title="Library" />
        <h1 className="sr-only">Library</h1>

        <div className="flex flex-col gap-10 sm:gap-[3vw]">
          <FeaturedCarousel
            sessions={featuredSessions}
            heroImagesById={featuredHeroImages}
          />
          <div className="flex flex-col gap-10 min-[120ch]:pl-[5vw] sm:gap-[3vw]">
            <LibraryHero
              continueWatching={continueWatching}
              backIcon={assets?.backIcon}
              thumbnails={thumbnails}
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
                      thumbnails={thumbnails}
                    />
                  </section>
                )
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
