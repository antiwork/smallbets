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

export default function FeaturedCarousel({
  sessions,
  thumbnails,
}: FeaturedCarouselProps) {
  const [api, setApi] = useState<CarouselApi>()
  const [current, setCurrent] = useState(0)
  const [count, setCount] = useState(0)
  const [isReady, setIsReady] = useState(false)

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

  const totalSlides = count || slides.length

  useEffect(() => {
    if (count > 0 || slides.length > 0) setIsReady(true)
  }, [count, slides.length])

  if (!hasSessions) return null

  return (
    <section
      aria-label="Featured sessions"
      className="relative mx-auto w-full max-w-7xl px-8 sm:px-12 md:px-16 lg:px-20"
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

        <div className="relative isolate mx-auto aspect-[16/9] w-[75%] sm:w-[80%] md:w-[85%] lg:aspect-[21/9] lg:w-[88%] xl:aspect-[5/2] xl:w-[92%]">
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
                  "bg-muted absolute inset-0 overflow-hidden rounded-3xl shadow-2xl transition-all duration-500",
                  "opacity-0",
                  isCurrent && "z-30 scale-100 opacity-100 shadow-black/40",
                  isPrevious &&
                    "z-20 -translate-x-[20%] scale-[0.90] opacity-70 md:-translate-x-[18%]",
                  isNext &&
                    "z-20 translate-x-[20%] scale-[0.90] opacity-70 md:translate-x-[18%]",
                  !isCurrent &&
                    !isPrevious &&
                    !isNext &&
                    "pointer-events-none opacity-0",
                )}
              >
                <div className="relative flex h-full flex-col justify-end">
                  {thumbnail ? (
                    <picture className="absolute inset-0 z-0 h-full w-full">
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
                    <div className="absolute inset-0 z-0 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800" />
                  )}

                  <div className="absolute inset-0 z-10 bg-[radial-gradient(circle_at_center,_rgba(12,12,18,0.55)_0%,_rgba(12,12,18,0.22)_55%,_rgba(14,14,20,0.72)_100%)]" />

                  <div
                    aria-hidden={!isCurrent}
                    className={cn(
                      "relative z-20 flex flex-col gap-4 p-10 text-white transition-all duration-500",
                      isCurrent
                        ? "translate-y-0 opacity-100"
                        : "pointer-events-none translate-y-6 opacity-0",
                    )}
                  >
                    <div className="max-w-[30ch]">
                      <h3 className="mt-2 text-3xl leading-tight font-semibold text-balance select-none sm:text-4xl">
                        {session.title}
                      </h3>
                    </div>

                    <div className="flex flex-wrap items-center gap-3">
                      <Button
                        size="lg"
                        className="rounded-lg bg-white! px-8 py-5 text-base font-semibold text-black shadow-lg transition hover:bg-white/90"
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
                </div>
              </article>
            )
          })}
        </div>

        <button
          type="button"
          aria-label="Previous slide"
          onClick={() => api?.scrollPrev()}
          className="absolute top-1/2 left-0 z-40 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/50 text-2xl text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none lg:flex"
        >
          <span aria-hidden>‹</span>
        </button>

        <button
          type="button"
          aria-label="Next slide"
          onClick={() => api?.scrollNext()}
          className="absolute top-1/2 right-0 z-40 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-black/50 text-2xl text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none lg:flex"
        >
          <span aria-hidden>›</span>
        </button>
      </div>

      <div
        className={cn(
          "relative z-30 mt-6 flex items-center justify-center gap-3 transition-opacity duration-250",
          isReady ? "opacity-100" : "opacity-0",
        )}
      >
        {Array.from({ length: totalSlides }).map((_, index) => {
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
                  ? "scale-[1.4] bg-white!"
                  : "bg-white/40! hover:bg-white/70!",
              )}
            />
          )
        })}
      </div>
    </section>
  )
}
