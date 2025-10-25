import { Head } from "@inertiajs/react"
import { useEffect, useMemo, useRef, useState } from "react"
import { createPortal } from "react-dom"

import { Button } from "@/components/ui/button"
import { MaskedIcon } from "@/components/ui/masked-icon"

import FeaturedCarousel from "./components/featured-carousel"
import LibraryHero from "./components/library_hero"
import SectionHeader from "./components/layout/section_header"
import SessionGrid from "./components/session_grid"
import { SearchBox, SearchResultsGrid } from "./components/search"
import type {
  LibrarySessionPayload,
  LibraryCategoryPayload,
  LibraryLayoutPayload,
  VimeoThumbnailPayload,
  LibraryAssetsPayload,
} from "./types"

interface LibraryPageProps {
  continueWatching: LibrarySessionPayload[]
  featuredSessions: LibrarySessionPayload[]
  sections: LibrarySectionPayload[]
  layout?: LayoutPayload
  initialSessionId?: number | null
  assets?: LibraryAssetsPayload
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
  const [query, setQuery] = useState("")
  const [navSearchRoot, setNavSearchRoot] = useState<HTMLElement | null>(null)
  const [bodyRoot, setBodyRoot] = useState<HTMLElement | null>(null)
  const [isMobileSearchOpen, setIsMobileSearchOpen] = useState(false)
  const mobileSearchButtonRef = useRef<HTMLButtonElement | null>(null)
  const mobileSearchInputRef = useRef<HTMLInputElement | null>(null)
  const wasMobileSearchOpen = useRef(false)
  const [navHeight, setNavHeight] = useState<number | null>(null)

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

  useEffect(() => {
    if (typeof window === "undefined") return
    const node = document.getElementById("library-search-root")
    setNavSearchRoot(node)
    setBodyRoot(document.body)
  }, [layout?.nav])

  useEffect(() => {
    if (!isMobileSearchOpen && wasMobileSearchOpen.current) {
      wasMobileSearchOpen.current = false
      mobileSearchButtonRef.current?.focus()
    }
    if (isMobileSearchOpen) {
      wasMobileSearchOpen.current = true
    }
  }, [isMobileSearchOpen])

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

  const trimmedQuery = query.trim()
  const normalizedQuery = trimmedQuery.replace(/\s+/g, "")
  const isActiveSearch = normalizedQuery.length >= 1

  const searchableSessions = useMemo(() => {
    const sessionMap = new Map<number, LibrarySessionPayload>()

    const addSessions = (sessionsToAdd: LibrarySessionPayload[]) => {
      sessionsToAdd.forEach((session) => {
        if (!sessionMap.has(session.id)) {
          sessionMap.set(session.id, session)
        }
      })
    }

    sections.forEach((section) => addSessions(section.sessions))
    addSessions(featuredSessions)
    addSessions(continueWatching)

    return Array.from(sessionMap.values())
  }, [sections, featuredSessions, continueWatching])

  const filteredSessions = useMemo(() => {
    if (!isActiveSearch) return []

    const tokens = trimmedQuery.toLowerCase().split(/\s+/).filter(Boolean)

    if (tokens.length === 0) return searchableSessions

    return searchableSessions.filter((session) => {
      const fields = [
        session.title,
        session.description,
        session.creator,
        ...session.categories.map((category) => category.name),
      ]
        .filter(Boolean)
        .map((field) => field.toLowerCase())

      return tokens.every((token) =>
        fields.some((field) => field.includes(token)),
      )
    })
  }, [isActiveSearch, trimmedQuery, searchableSessions])

  useEffect(() => {
    if (!isMobileSearchOpen) return

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault()
        setIsMobileSearchOpen(false)
      }
    }

    window.addEventListener("keydown", handleKeyDown)
    return () => window.removeEventListener("keydown", handleKeyDown)
  }, [isMobileSearchOpen])

  useEffect(() => {
    if (!isMobileSearchOpen) {
      return
    }
    const frame = requestAnimationFrame(() => {
      mobileSearchInputRef.current?.focus()
      mobileSearchInputRef.current?.select()
    })
    return () => cancelAnimationFrame(frame)
  }, [isMobileSearchOpen])

  useEffect(() => {
    if (!isMobileSearchOpen) return
    const navEl = document.getElementById("nav")
    if (!navEl) return
    const compute = () => setNavHeight(navEl.getBoundingClientRect().height)
    compute()
    window.addEventListener("resize", compute)
    return () => window.removeEventListener("resize", compute)
  }, [isMobileSearchOpen])

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
    <div
      className={`bg-background mt-[3vw] py-12 ${isActiveSearch ? "" : "min-h-screen"}`}
    >
      <div className="pb-16">
        <Head title="Library" />
        <h1 className="sr-only">Library</h1>

        {navSearchRoot
          ? createPortal(
              <>
                <SearchBox
                  iconSrc={assets?.searchIcon}
                  value={query}
                  onChange={setQuery}
                  containerClassName="hidden sm:flex"
                />

                <div className="relative mr-13 ml-auto flex items-center sm:hidden!">
                  <Button
                    ref={mobileSearchButtonRef}
                    type="button"
                    variant="ghost"
                    size="icon-lg"
                    className="border-input bg-background size-10 rounded-full border shadow-[0_0_0_1px_var(--control-border)]"
                    aria-label="Open search"
                    aria-expanded={isMobileSearchOpen}
                    aria-controls="library-search-dialog"
                    onClick={() => setIsMobileSearchOpen(true)}
                  >
                    <MaskedIcon src={assets?.searchIcon} />
                  </Button>

                  {isMobileSearchOpen && bodyRoot
                    ? createPortal(
                        <div
                          id="library-search-dialog"
                          role="dialog"
                          aria-modal="true"
                          aria-label="Search library"
                          className="bg-background/95 fixed inset-x-0 top-0 z-[10000] flex items-center gap-3 px-2 py-2 shadow-[0_1px_0_0_var(--control-border)] backdrop-blur sm:hidden!"
                          style={{ height: navHeight ?? undefined }}
                        >
                          <button
                            type="button"
                            className="border-input bg-background flex size-10 items-center justify-center rounded-full border shadow-[0_0_0_1px_var(--control-border)]"
                            aria-label="Close search"
                            onClick={() => setIsMobileSearchOpen(false)}
                          >
                            <MaskedIcon src={assets?.backIcon} />
                          </button>
                          <SearchBox
                            iconSrc={assets?.searchIcon}
                            value={query}
                            onChange={setQuery}
                            containerClassName="mr-0 ml-0 max-w-none flex-1"
                            inputId="library-search-mobile"
                            ref={mobileSearchInputRef}
                          />
                        </div>,
                        bodyRoot,
                      )
                    : null}
                </div>
              </>,
              navSearchRoot,
            )
          : null}

        <div className="flex flex-col gap-10 sm:gap-[3vw]">
          {isActiveSearch ? (
            <SearchResultsGrid
              sessions={filteredSessions}
              thumbnails={thumbnails}
              backIcon={assets?.backIcon}
            />
          ) : (
            <>
              <FeaturedCarousel
                sessions={featuredSessions}
                heroImagesById={featuredHeroImages}
                className="opacity-100 transition-opacity duration-200"
              />
              <div className="flex flex-col gap-10 transition-opacity duration-200 min-[120ch]:pl-[5vw] sm:gap-[3vw]">
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
                        <SectionHeader
                          id={headingId}
                          title={group.category.name}
                        />
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
            </>
          )}
        </div>
      </div>
    </div>
  )
}
