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

  function navigateToSession(sessionId: string) {
    router.visit(`/library/${sessionId}`, { preserveScroll: true })
  }

  useEffect(() => {
    if (count > 0 || slides.length > 0) setIsReady(true)
  }, [count, slides.length])

  if (!hasSessions) return null

  return (
    <section
      aria-label="Featured sessions"
      className="relative mx-auto w-full max-w-7xl px-8 pt-8 select-none sm:px-12 md:px-16 lg:px-20 lg:pt-4 xl:pt-0"
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

        <div className="relative isolate mx-auto aspect-[16/9] w-[75%] sm:w-[80%] md:w-[85%] lg:aspect-[21/9] lg:w-[88%] xl:aspect-[5/2] xl:w-[90%] 2xl:w-[95%]">
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
                        className="hidden items-center gap-3 rounded-lg bg-white! px-8 py-5 text-base font-semibold text-black shadow-lg transition hover:bg-white/90 sm:inline-flex"
                        onClick={() => navigateToSession(session.id)}
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          xmlns="http://www.w3.org/2000/svg"
                          aria-hidden
                          focusable="false"
                          className="-ml-1 size-5 shrink-0"
                        >
                          <path
                            d="M7.1634 5.26359C6.47653 5.61065 6 6.26049 6 7.17893V16.8099C6 18.6468 7.94336 19.5276 9.54792 18.6696L17.1109 14.6211C19.676 13.1239 19.5829 10.8124 17.1109 9.3678L9.54792 5.3184C8.74564 4.88956 7.85027 4.91669 7.1634 5.26359Z"
                            fill="currentColor"
                          />
                        </svg>
                        Watch Now
                      </Button>
                    </div>
                  </div>
                </div>
                {isCurrent && (
                  <button
                    type="button"
                    aria-label={`Watch ${session.title}`}
                    className="absolute inset-0 z-30 cursor-pointer bg-transparent focus:outline-none focus-visible:ring-2 focus-visible:ring-white/60 sm:hidden"
                    onClick={() => navigateToSession(session.id)}
                  >
                    <span className="sr-only">Watch {session.title}</span>
                  </button>
                )}
              </article>
            )
          })}
        </div>

        <button
          type="button"
          aria-label="Previous slide"
          onClick={() => api?.scrollPrev()}
          className="group absolute top-1/2 left-[-12vw] z-40 hidden size-25 -translate-y-1/2 items-center justify-center bg-neutral-100 transition-all duration-200 ease-out hover:bg-neutral-200 hover:shadow-none! focus-visible:ring-2 focus-visible:ring-neutral-900/60 focus-visible:outline-none 2xl:flex dark:bg-neutral-800 dark:hover:bg-neutral-700 dark:focus-visible:ring-white/70"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden
            className="size-9 transition-transform duration-200 ease-out group-hover:-translate-x-1"
          >
            <path
              d="M9.62132 12L8.56066 13.1112C7.97487 13.7248 7.02513 13.7248 6.43934 13.1112C5.85355 12.4975 5.85355 11.5025 6.43934 10.8888L15.4393 1.46026C16.0251 0.84658 16.9749 0.84658 17.5607 1.46026C18.1464 2.07394 18.1464 3.06891 17.5607 3.6826L9.62132 12L17.5607 20.3174C18.1464 20.9311 18.1464 21.9261 17.5607 22.5397C16.9749 23.1534 16.0251 23.1534 15.4393 22.5397L6.43934 13.1112C5.85355 12.4975 5.85355 11.5025 6.43934 10.8888C7.02513 10.2751 7.97487 10.2751 8.56066 10.8888L9.62132 12Z"
              className="fill-neutral-900 transition-colors dark:fill-white"
            />
          </svg>
        </button>

        <button
          type="button"
          aria-label="Next slide"
          onClick={() => api?.scrollNext()}
          className="group absolute top-1/2 right-[-12vw] z-40 hidden size-25 -translate-y-1/2 items-center justify-center bg-neutral-100 transition-all duration-200 ease-out hover:bg-neutral-200 hover:shadow-none! focus-visible:ring-2 focus-visible:ring-neutral-900/60 focus-visible:outline-none 2xl:flex dark:bg-neutral-800 dark:hover:bg-neutral-700 dark:focus-visible:ring-white/70"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden
            className="size-9 transition-transform duration-200 ease-out group-hover:translate-x-1"
          >
            <path
              d="M14.3787 12L15.4393 10.8888C16.0251 10.2752 16.9749 10.2752 17.5607 10.8888C18.1464 11.5025 18.1464 12.4975 17.5607 13.1112L8.56066 22.5397C7.97487 23.1534 7.02512 23.1534 6.43934 22.5397C5.85355 21.9261 5.85355 20.9311 6.43934 20.3174L14.3787 12L6.43934 3.6826C5.85355 3.06892 5.85355 2.07395 6.43934 1.46026C7.02513 0.846584 7.97487 0.846584 8.56066 1.46026L17.5607 10.8888C18.1464 11.5025 18.1464 12.4975 17.5607 13.1112C16.9749 13.7249 16.0251 13.7249 15.4393 13.1112L14.3787 12Z"
              className="fill-neutral-900 transition-colors dark:fill-white"
            />
          </svg>
        </button>
      </div>

      <div
        className={cn(
          "relative z-30 mt-6 flex items-center justify-center gap-0 transition-opacity duration-250",
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
              className="group flex size-11 items-center justify-center ring-0! ring-offset-0! outline-none! hover:ring-0! hover:ring-offset-0! hover:outline-none! focus:ring-0! focus:ring-offset-0! focus:outline-none! focus-visible:ring-2! focus-visible:ring-neutral-900/60! focus-visible:ring-offset-2! focus-visible:ring-offset-transparent! focus-visible:outline-none! md:size-8 dark:focus-visible:ring-white/70!"
            >
              <span
                className={cn(
                  "size-2.5 rounded-full transition-all",
                  isActive
                    ? "scale-[1.4] bg-neutral-950! dark:bg-white!"
                    : "bg-neutral-400! group-hover:bg-neutral-600! dark:bg-white/40! dark:group-hover:bg-white/70!",
                )}
              />
            </button>
          )
        })}
      </div>
    </section>
  )
}
