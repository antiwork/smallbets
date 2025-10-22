"use client"

import { useState } from "react"
import { router } from "@inertiajs/react"

import {
  Carousel,
  CarouselContent,
  CarouselItem,
  type CarouselApi,
} from "@/components/ui/carousel"

import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"
import { useSlides, useCarouselState, useDragNavigation } from "./hooks"
import { Slide } from "./slide"
import { NavButtons } from "./nav-buttons"
import { Indicators } from "./indicators"

export interface FeaturedCarouselProps {
  sessions: LibrarySessionPayload[]
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

export function FeaturedCarousel({
  sessions,
  thumbnails,
}: FeaturedCarouselProps) {
  const [api, setApi] = useState<CarouselApi>()

  const hasSessions = sessions.length > 0
  if (!hasSessions) return null

  const slides = useSlides(sessions, thumbnails)
  const { current, count, isReady } = useCarouselState(api, slides.length)
  const totalSlides = count || slides.length

  function navigateToSession(sessionId: string | number) {
    router.visit(`/library/${String(sessionId)}`, { preserveScroll: true })
  }

  const drag = useDragNavigation(api)

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
              <Slide
                key={session.id}
                session={session}
                thumbnail={thumbnail}
                isCurrent={isCurrent}
                isPrevious={isPrevious}
                isNext={isNext}
                drag={drag}
                onWatch={navigateToSession}
              />
            )
          })}
        </div>

        <NavButtons api={api} />
      </div>

      <Indicators
        current={current}
        total={totalSlides}
        isReady={isReady}
        goTo={(i) => api?.scrollTo(i)}
      />
    </section>
  )
}

export default FeaturedCarousel
