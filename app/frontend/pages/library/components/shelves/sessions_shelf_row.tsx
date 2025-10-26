import { useEffect, useMemo, useState } from "react"
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  type CarouselApi,
} from "@/components/ui/carousel"
import VideoCard from "../video_card"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"
import { useShelfItems } from "./use-shelf-items"

export function SessionsShelfRow({
  sessions,
  backIcon,
  title,
  showProgress = false,
  persistPreview = false,
  thumbnails,
  id,
}: {
  sessions: LibrarySessionPayload[]
  backIcon?: string
  title?: string
  showProgress?: boolean
  persistPreview?: boolean
  thumbnails?: Record<string, VimeoThumbnailPayload>
  id?: string
}) {
  const [api, setApi] = useState<CarouselApi>()
  const [canScrollPrev, setCanScrollPrev] = useState(false)
  const [canScrollNext, setCanScrollNext] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(0)
  const batchSize = useShelfItems()

  const batches = useMemo(() => {
    const result: LibrarySessionPayload[][] = []
    for (let i = 0; i < sessions.length; i += batchSize) {
      result.push(sessions.slice(i, i + batchSize))
    }
    if (result.length > 0 && sessions.length > 0) {
      result.push([sessions[0]])
    }
    return result
  }, [sessions, batchSize])

  useEffect(() => {
    if (!api) return

    const updateScrollState = () => {
      setCanScrollPrev(api.canScrollPrev())
      const isOnSecondToLast = api.selectedScrollSnap() === batches.length - 2
      setCanScrollNext(api.canScrollNext() && !isOnSecondToLast)
      const totalReal = Math.max(0, batches.length - 1)
      const selected = api.selectedScrollSnap()
      setSelectedIndex(Math.min(selected, Math.max(0, totalReal - 1)))
    }

    // Ensure carousel is fully initialized
    const timer = setTimeout(() => {
      updateScrollState()
    }, 0)

    api.on("select", updateScrollState)
    api.on("reInit", updateScrollState)
    api.on("settle", updateScrollState)

    return () => {
      clearTimeout(timer)
      api.off("select", updateScrollState)
      api.off("reInit", updateScrollState)
      api.off("settle", updateScrollState)
    }
  }, [api, batches.length])

  const scrollPrev = () => {
    api?.scrollPrev()
  }

  const scrollNext = () => {
    api?.scrollNext()
  }

  if (sessions.length === 0) return null

  const headingId = title
    ? `shelf-${title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "")}`
    : undefined

  return (
    <section
      id={id}
      tabIndex={id ? -1 : undefined}
      className="shelf-scope flex flex-col gap-[1vw]"
      aria-labelledby={headingId}
    >
      {/* Live region announcing the current batch for screen readers */}
      {batches.length > 1 ? (
        <div
          className="sr-only"
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          {`${Math.min(selectedIndex + 1, Math.max(1, batches.length - 1))} of ${Math.max(1, batches.length - 1)}`}
        </div>
      ) : null}
      {title ? (
        <h2
          id={headingId}
          className="text-foreground !pl-[var(--shelf-side-pad)] text-xl leading-tight font-medium tracking-wider capitalize select-none"
        >
          {title}
        </h2>
      ) : null}
      <div
        className="group/shelf relative"
        style={{ ["--shelf-container-w" as any]: "100%" }}
      >
        <Carousel
          opts={{
            align: "start",
            loop: false,
            slidesToScroll: 1,
          }}
          setApi={setApi}
          className="w-full"
          aria-roledescription="carousel"
          aria-label={title ? `${title} videos` : "Videos"}
        >
          <CarouselContent className="!mr-[var(--shelf-side-pad)] !ml-[var(--shelf-side-pad)] pb-[0.4vw]">
            {batches.map((batch, batchIndex) => {
              const isPhantomSlide = batchIndex === batches.length - 1

              // Only render current slide and immediate neighbors to reduce DOM/update work
              const isVisibleSlide =
                batchIndex === selectedIndex ||
                batchIndex === selectedIndex - 1 ||
                batchIndex === selectedIndex + 1 ||
                isPhantomSlide

              return (
                <CarouselItem
                  key={batchIndex}
                  className="!basis-[calc(100vw_-_var(--shelf-side-pad)_*_2)] !p-0"
                  aria-hidden={isPhantomSlide ? true : undefined}
                >
                  {isPhantomSlide ? (
                    <div className="pointer-events-none opacity-0">
                      <div className="aspect-[16/9] w-[var(--shelf-card-w)] shrink-0" />
                    </div>
                  ) : isVisibleSlide ? (
                    <div className="flex gap-[var(--shelf-gap)]">
                      {batch.map((session) => (
                        <div
                          key={session.id}
                          className="w-[var(--shelf-card-w)] shrink-0"
                        >
                          <VideoCard
                            session={session}
                            backIcon={backIcon}
                            showProgress={showProgress}
                            persistPreview={persistPreview}
                            thumbnail={thumbnails?.[session.vimeoId]}
                          />
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="flex gap-[var(--shelf-gap)]">
                      {batch.map((session) => (
                        <div
                          key={session.id}
                          className="aspect-[16/9] w-[var(--shelf-card-w)] shrink-0"
                        />
                      ))}
                    </div>
                  )}
                </CarouselItem>
              )
            })}
          </CarouselContent>
        </Carousel>

        {canScrollPrev && (
          <button
            type="button"
            onClick={scrollPrev}
            aria-label="Show previous videos"
            className="absolute top-0 bottom-0 left-0 z-10 flex w-[var(--shelf-side-pad)] cursor-pointer items-start justify-center bg-gradient-to-r from-white/90 to-white/50 !shadow-none transition-opacity duration-200 focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:outline-none dark:from-black/90 dark:to-black/50"
            style={{
              paddingTop: "calc(var(--shelf-card-w) * 9 / 16 / 2 - 8px)",
            }}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="hidden size-9 text-gray-800 opacity-0 transition-opacity duration-200 group-hover/shelf:opacity-100 sm:block dark:text-white"
              aria-hidden="true"
            >
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </button>
        )}

        {canScrollNext && (
          <button
            type="button"
            onClick={scrollNext}
            aria-label="Show next videos"
            className="absolute top-0 right-0 bottom-0 z-10 flex w-[var(--shelf-side-pad)] cursor-pointer items-start justify-center bg-gradient-to-l from-white/90 to-white/50 !shadow-none transition-opacity duration-200 focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:outline-none dark:from-black/90 dark:to-black/50"
            style={{
              paddingTop: "calc(var(--shelf-card-w) * 9 / 16 / 2 - 8px)",
            }}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="hidden size-9 text-gray-800 opacity-0 transition-opacity duration-200 group-hover/shelf:opacity-100 sm:block dark:text-white"
              aria-hidden="true"
            >
              <polyline points="9 18 15 12 9 6" />
            </svg>
          </button>
        )}
      </div>
    </section>
  )
}
