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
      className="flex flex-col gap-[1vw]"
      aria-labelledby={headingId}
    >
      {title ? (
        <h2
          id={headingId}
          className="text-foreground pl-1 text-xl leading-tight font-medium tracking-wider capitalize select-none"
        >
          {title}
        </h2>
      ) : null}
      <div className="relative">
        <Carousel
          opts={{
            align: "start",
            loop: false,
            slidesToScroll: 1,
          }}
          setApi={setApi}
          className="w-full [--shelf-card-w:calc((100vw_-_var(--shelf-gap)_*_2)/(2_+_0.3))] [--shelf-gap:0.8vw] [--shelf-items:2] [--shelf-peek:0.15] md:[--shelf-card-w:calc((100vw_-_var(--shelf-gap)_*_3)/(3_+_0.3))] md:[--shelf-items:3] lg:[--shelf-card-w:calc((100vw_-_var(--shelf-gap)_*_4)/(4_+_0.3))] lg:[--shelf-items:4] xl:[--shelf-card-w:calc((100vw_-_var(--shelf-gap)_*_5)/(5_+_0.3))] xl:[--shelf-items:5] 2xl:[--shelf-card-w:calc((100vw_-_var(--library-left-pad,0px)_*_2_-_var(--shelf-gap)_*_6)/6)] 2xl:[--shelf-items:6]"
        >
          <CarouselContent className="!ml-[calc(var(--shelf-card-w)*var(--shelf-peek))] pb-[0.4vw] 2xl:!ml-[var(--library-left-pad,0px)]">
            {batches.map((batch, batchIndex) => {
              const isPhantomSlide = batchIndex === batches.length - 1

              return (
                <CarouselItem
                  key={batchIndex}
                  className="!basis-[calc(100vw_-_var(--shelf-card-w)_*_var(--shelf-peek)_*_2)] !p-0 2xl:!basis-[calc(100vw_-_var(--library-left-pad,0px)_*_2)]"
                  aria-hidden={isPhantomSlide ? true : undefined}
                  inert={isPhantomSlide ? true : undefined}
                >
                  {isPhantomSlide ? (
                    <div className="pointer-events-none opacity-0">
                      <div className="aspect-[16/9] w-[var(--shelf-card-w)] shrink-0" />
                    </div>
                  ) : (
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
            className="absolute top-0 bottom-[0.4vw] left-0 z-10 flex w-[calc(var(--shelf-card-w)*var(--shelf-peek))] cursor-pointer items-center justify-center bg-gradient-to-r from-black/60 to-transparent opacity-0 transition-opacity duration-200 hover:opacity-100"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="h-8 w-8 text-white"
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
            className="absolute top-0 right-0 bottom-[0.4vw] z-10 flex w-[calc(var(--shelf-card-w)*var(--shelf-peek))] cursor-pointer items-center justify-center bg-gradient-to-l from-black/60 to-transparent opacity-0 transition-opacity duration-200 hover:opacity-100 focus:opacity-100"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="h-8 w-8 text-white"
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
