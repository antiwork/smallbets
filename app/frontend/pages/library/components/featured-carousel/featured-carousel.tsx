"use client"

import { useState } from "react"
import type { HTMLAttributes } from "react"
import { router } from "@inertiajs/react"

import {
  Carousel,
  CarouselContent,
  CarouselItem,
  type CarouselApi,
} from "@/components/ui/carousel"

import type { LibrarySessionPayload } from "../../types"
import { cn } from "@/lib/utils"
import {
  useSlides,
  useCarouselState,
  useDragNavigation,
  useAutoplay,
} from "./hooks"
import { Slide } from "./slide"
import { NavButtons } from "./nav-buttons"
import { Indicators } from "./indicators"

export interface FeaturedCarouselProps extends HTMLAttributes<HTMLElement> {
  sessions: LibrarySessionPayload[]
  heroImagesById?: Record<string, string>
}

export function FeaturedCarousel({
  sessions,
  heroImagesById,
  className,
  ...sectionProps
}: FeaturedCarouselProps) {
  const [api, setApi] = useState<CarouselApi>()

  const hasSessions = sessions.length > 0
  if (!hasSessions) return null

  const slides = useSlides(sessions, heroImagesById)
  const { current, count, isReady } = useCarouselState(api, slides.length)
  const totalSlides = count || slides.length

  const autoplay = useAutoplay(api)

  function navigateToSession(sessionId: string | number) {
    autoplay.stop()
    router.visit(`/library/${String(sessionId)}`, { preserveScroll: true })
  }

  const drag = useDragNavigation(api, 100, () => autoplay.stop())

  function onRegionKeyDown(e: React.KeyboardEvent<HTMLElement>) {
    if (e.target !== e.currentTarget) return
    if (e.key === "ArrowLeft") {
      e.preventDefault()
      autoplay.stop()
      api?.scrollPrev()
    } else if (e.key === "ArrowRight") {
      e.preventDefault()
      autoplay.stop()
      api?.scrollNext()
    }
  }

  function onRegionBlur(e: React.FocusEvent<HTMLElement>) {
    const next = e.relatedTarget as Node | null
    if (next && e.currentTarget.contains(next)) return
    if (e.currentTarget.matches(":hover")) return
    autoplay.resume()
  }

  return (
    <section
      role="region"
      aria-roledescription="carousel"
      aria-describedby="featured-carousel-instructions"
      aria-label="Featured sessions"
      tabIndex={0}
      onKeyDown={onRegionKeyDown}
      onFocus={() => autoplay.pause()}
      onBlur={onRegionBlur}
      onMouseEnter={() => autoplay.pause()}
      onMouseLeave={() => autoplay.resume()}
      className={cn(
        "relative mx-auto w-full max-w-7xl px-8 pt-8 select-none focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:ring-offset-2 focus-visible:outline-none sm:px-12 md:px-16 lg:px-20 lg:pt-4 xl:pt-0 dark:focus-visible:ring-[#00ADEF]",
        className,
      )}
      {...sectionProps}
    >
      <div className="relative">
        <Carousel
          aria-hidden
          tabIndex={-1}
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

        <div className="relative isolate mx-auto aspect-[16/9] w-full sm:w-[80%] md:w-[85%] lg:aspect-[21/9] lg:w-[88%] xl:aspect-[5/2] xl:w-[85%] 2xl:w-[90%]">
          {slides.map(({ session, imageSrc }, index) => {
            const position = (index - current + count) % count
            const isPrevious = position === count - 1
            const isNext = position === 1
            const isCurrent = position === 0

            return (
              <Slide
                key={session.id}
                session={session}
                imageSrc={imageSrc}
                isCurrent={isCurrent}
                isPrevious={isPrevious}
                isNext={isNext}
                drag={drag}
                onWatch={navigateToSession}
              />
            )
          })}
        </div>

        <NavButtons api={api} onInteract={() => autoplay.stop()} />
      </div>

      <p id="featured-carousel-instructions" className="sr-only">
        Use Left and Right arrow keys to navigate featured slides.
      </p>
      <p
        id="featured-carousel-status"
        className="sr-only"
        aria-live="polite"
        aria-atomic="true"
      >
        {`Slide ${current + 1} of ${totalSlides}: ${slides[current]?.session.title ?? ""}`}
      </p>

      <Indicators
        current={current}
        total={totalSlides}
        isReady={isReady}
        goTo={(i) => api?.scrollTo(i)}
        onInteract={() => autoplay.stop()}
      />
    </section>
  )
}

export default FeaturedCarousel
