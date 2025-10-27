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

interface SessionCellProps {
  session: LibrarySessionPayload
  mounted: boolean
  backIcon?: string
  showProgress: boolean
  persistPreview: boolean
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

function SessionCell({
  session,
  mounted,
  backIcon,
  showProgress,
  persistPreview,
  thumbnails,
}: SessionCellProps) {
  return (
    <div className="w-[var(--shelf-card-w)] shrink-0">
      {mounted ? (
        <VideoCard
          session={session}
          backIcon={backIcon}
          showProgress={showProgress}
          persistPreview={persistPreview}
          thumbnail={thumbnails?.[session.vimeoId]}
          imageLoading={"eager"}
          fetchPriority={"high"}
        />
      ) : (
        <div className="aspect-[16/9] w-full" />
      )}
    </div>
  )
}

interface NavigationButtonProps {
  direction: "prev" | "next"
  onClick: () => void
}

function NavigationButton({ direction, onClick }: NavigationButtonProps) {
  const isPrev = direction === "prev"

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={isPrev ? "Show previous videos" : "Show next videos"}
      className={`shelf-nav-btn absolute top-0 bottom-0 z-[2] flex w-[var(--shelf-side-pad)] cursor-pointer items-start justify-center !shadow-none transition-opacity duration-250 ease-out before:absolute before:inset-0 before:from-white/80 before:to-white/10 group-hover/shelf:before:opacity-0 focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:outline-none dark:before:from-black/80 dark:before:to-black/20 ${
        isPrev
          ? "left-0 before:bg-gradient-to-r"
          : "right-0 before:bg-gradient-to-l"
      }`}
      style={{
        paddingTop: "calc(var(--shelf-card-w) * 9 / 16 / 2 - 12px)",
      }}
    >
      <div className="relative z-[1] hidden size-8 items-center justify-center rounded-full bg-white opacity-0 shadow-[0_0_0_1px_var(--control-border)] transition-opacity duration-150 ease-out group-hover/shelf:opacity-100 sm:flex dark:bg-black">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="size-6 text-black dark:text-white"
          aria-hidden="true"
        >
          <polyline points={isPrev ? "15 18 9 12 15 6" : "9 18 15 12 9 6"} />
        </svg>
      </div>
    </button>
  )
}

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
      const lastIndex = batches.length - 1
      const lastRealIndex = Math.max(0, lastIndex - 1)
      const selected = api.selectedScrollSnap()

      // Prevent selecting the phantom last slide when dragging
      if (selected === lastIndex) {
        api.scrollTo(lastRealIndex)
        return
      }

      setCanScrollPrev(api.canScrollPrev())
      const isOnSecondToLast = selected === batches.length - 2
      setCanScrollNext(api.canScrollNext() && !isOnSecondToLast)
      const totalReal = Math.max(0, batches.length - 1)
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
        className="group/shelf relative z-0"
        style={{ ["--shelf-container-w" as any]: "100%" }}
      >
        <Carousel
          opts={{
            align: "start",
            loop: false,
            slidesToScroll: 1,
            duration: 20,
            containScroll: "trimSnaps",
          }}
          setApi={setApi}
          className="w-full"
          aria-roledescription="carousel"
          aria-label={title ? `${title} videos` : "Videos"}
        >
          <CarouselContent className="!mr-[var(--shelf-side-pad)] !ml-[var(--shelf-side-pad)] pb-[0.4vw]">
            {batches.map((batch, batchIndex) => {
              const isPhantomSlide = batchIndex === batches.length - 1

              const itemKey = isPhantomSlide
                ? "phantom"
                : `batch-${batch[0]?.id ?? batchIndex}-${batch.length}`

              return (
                <CarouselItem
                  key={itemKey}
                  className="!basis-[calc(100vw_-_var(--shelf-side-pad)_*_2)] !p-0"
                  aria-hidden={isPhantomSlide ? true : undefined}
                >
                  {isPhantomSlide ? (
                    <div className="pointer-events-none opacity-0">
                      <div className="aspect-[16/9] w-[var(--shelf-card-w)] shrink-0" />
                    </div>
                  ) : (
                    <div className="flex gap-[var(--shelf-gap)]">
                      {batch.map((session) => (
                        <SessionCell
                          key={session.id}
                          session={session}
                          mounted={true}
                          backIcon={backIcon}
                          showProgress={showProgress}
                          persistPreview={persistPreview}
                          thumbnails={thumbnails}
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
          <NavigationButton direction="prev" onClick={scrollPrev} />
        )}
        {canScrollNext && (
          <NavigationButton direction="next" onClick={scrollNext} />
        )}
      </div>
    </section>
  )
}
