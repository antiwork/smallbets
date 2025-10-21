"use client"

import { useEffect, useMemo, useState } from "react"
import { router } from "@inertiajs/react"

import { Button } from "@/components/ui/button"
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  type CarouselApi,
} from "@/components/ui/carousel"
import { cn } from "@/lib/utils"

import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../types"

interface FeaturedCarouselProps {
  sessions: LibrarySessionPayload[]
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

function formatDescription(text: string): string {
  return text.length > 160 ? `${text.slice(0, 157)}...` : text
}

export default function FeaturedCarousel({
  sessions,
  thumbnails,
}: FeaturedCarouselProps) {
  const [api, setApi] = useState<CarouselApi>()
  const [current, setCurrent] = useState(0)
  const [count, setCount] = useState(0)

  useEffect(() => {
    if (!api) return

    const syncState = () => {
      setCount(api.scrollSnapList().length)
      setCurrent(api.selectedScrollSnap())
    }

    syncState()
    api.on("select", syncState)

    return () => {
      api.off("select", syncState)
    }
  }, [api])

  const hasSessions = sessions.length > 0

  const slides = useMemo(
    () =>
      sessions.map((session) => {
        const thumbnail = thumbnails?.[session.vimeoId]
        return { session, thumbnail }
      }),
    [sessions, thumbnails],
  )

  if (!hasSessions) return null

  return (
    <section
      aria-label="Featured sessions"
      className="relative mx-auto w-full max-w-7xl px-4"
    >
      <div className="relative">
        <Carousel
          setApi={setApi}
          opts={{ align: "center", loop: true, skipSnaps: false }}
          className="group/carousel invisible absolute"
        >
          <CarouselContent>
            {slides.map(({ session }) => (
              <CarouselItem key={session.id} className="basis-full" />
            ))}
          </CarouselContent>
        </Carousel>

        <div className="relative mx-auto h-[32rem] w-full md:h-[36rem]">
          {slides.map(({ session, thumbnail }, index) => {
            const position = (index - current + count) % count
            const isPrevious = position === count - 1
            const isNext = position === 1
            const isCurrent = position === 0

            return (
              <article
                key={session.id}
                role="group"
                aria-roledescription="slide"
                aria-label={`${session.title}`}
                className={cn(
                  "bg-muted absolute inset-0 flex h-full min-h-[32rem] flex-col justify-end overflow-hidden rounded-[2rem] shadow-xl transition-all duration-500 md:min-h-[36rem]",
                  "before:absolute before:inset-0 before:bg-gradient-to-t before:from-black/80 before:via-black/20 before:to-transparent",
                  isCurrent && "z-30 scale-100 shadow-black/40",
                  isPrevious &&
                    "z-20 -translate-x-[40%] scale-[0.85] opacity-60",
                  isNext && "z-20 translate-x-[40%] scale-[0.85] opacity-60",
                  !isCurrent &&
                    !isPrevious &&
                    !isNext &&
                    "pointer-events-none opacity-0",
                )}
              >
                {thumbnail ? (
                  <picture className="absolute inset-0 h-full w-full">
                    <source srcSet={thumbnail.srcset} />
                    <img
                      src={thumbnail.src}
                      alt=""
                      loading="lazy"
                      decoding="async"
                      width={thumbnail.width}
                      height={thumbnail.height}
                      className="h-full w-full object-cover"
                    />
                  </picture>
                ) : (
                  <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800" />
                )}

                <div className="relative z-10 flex flex-col gap-4 p-10 text-white">
                  <div className="max-w-[30ch]">
                    <p className="text-sm tracking-[0.3em] text-white/70 uppercase">
                      Featured Session
                    </p>
                    <h3 className="mt-2 text-3xl leading-tight font-semibold text-balance sm:text-4xl">
                      {session.title}
                    </h3>
                    <p className="mt-4 hidden text-base leading-relaxed text-white/80 md:block">
                      {formatDescription(session.description)}
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-3">
                    <Button
                      size="lg"
                      className="rounded-full bg-white/95 px-8 py-5 text-base font-semibold text-black shadow-lg transition hover:bg-white"
                      onClick={() => {
                        router.visit(`/library/${session.id}`, {
                          preserveScroll: true,
                        })
                      }}
                    >
                      Watch Now
                    </Button>
                  </div>
                </div>
              </article>
            )
          })}
        </div>

        <button
          type="button"
          aria-label="Previous slide"
          onClick={() => api?.scrollPrev()}
          className="absolute top-1/2 left-4 z-40 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/50 text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none sm:flex"
        >
          <span aria-hidden>‹</span>
        </button>

        <button
          type="button"
          aria-label="Next slide"
          onClick={() => api?.scrollNext()}
          className="absolute top-1/2 right-4 z-40 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/50 text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none sm:flex"
        >
          <span aria-hidden>›</span>
        </button>
      </div>

      <div className="mt-6 flex items-center justify-center gap-3">
        {Array.from({ length: count }).map((_, index) => {
          const isActive = index === current
          return (
            <button
              key={index}
              type="button"
              aria-label={`Go to slide ${index + 1}`}
              aria-current={isActive}
              onClick={() => api?.scrollTo(index)}
              className={cn(
                "h-2.5 w-2.5 rounded-full transition",
                isActive
                  ? "scale-[1.4] bg-white"
                  : "bg-white/40 hover:bg-white/70",
              )}
            />
          )
        })}
      </div>
    </section>
  )
}
