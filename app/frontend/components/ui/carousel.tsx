"use client"

import * as React from "react"
import useEmblaCarousel from "embla-carousel-react"
import type {
  EmblaOptionsType,
  EmblaPluginType,
  EmblaCarouselType,
} from "embla-carousel"

import { cn } from "@/lib/utils"

type CarouselApi = EmblaCarouselType
type UseEmblaCarouselType = typeof useEmblaCarousel

type CarouselProps = {
  orientation?: "horizontal" | "vertical"
  opts?: EmblaOptionsType
  plugins?: EmblaPluginType[]
  setApi?: (api: CarouselApi | undefined) => void
} & React.HTMLAttributes<HTMLDivElement>

const CarouselContext = React.createContext<{
  carouselRef: ReturnType<UseEmblaCarouselType>[0]
  api: CarouselApi | undefined
  orientation: "horizontal" | "vertical"
} | null>(null)

function useCarousel(): {
  carouselRef: ReturnType<UseEmblaCarouselType>[0]
  api: CarouselApi | undefined
  orientation: "horizontal" | "vertical"
} {
  const context = React.useContext(CarouselContext)
  if (!context) {
    throw new Error("useCarousel must be used within a <Carousel>")
  }
  return context
}

function Carousel({
  orientation = "horizontal",
  opts,
  plugins,
  setApi,
  className,
  children,
  ...props
}: CarouselProps) {
  const [carouselRef, api] = useEmblaCarousel(
    {
      axis: orientation === "horizontal" ? "x" : "y",
      ...opts,
    },
    plugins,
  )

  React.useEffect(() => {
    if (!setApi) return
    setApi(api ?? undefined)
  }, [api, setApi])

  const contextValue = React.useMemo(
    () => ({ carouselRef, api: api ?? undefined, orientation }),
    [carouselRef, api, orientation],
  )

  return (
    <CarouselContext.Provider value={contextValue}>
      <div
        data-orientation={orientation}
        className={cn(
          "relative",
          orientation === "horizontal" ? "w-full" : "flex h-full",
          className,
        )}
        {...props}
      >
        {children}
      </div>
    </CarouselContext.Provider>
  )
}

type CarouselContentProps = React.HTMLAttributes<HTMLDivElement>

const CarouselContent = React.forwardRef<HTMLDivElement, CarouselContentProps>(
  ({ className, children, ...props }, ref) => {
    const { carouselRef, orientation } = useCarousel()

    return (
      <div ref={carouselRef} className="overflow-hidden">
        <div
          ref={ref}
          className={cn(
            "flex gap-0",
            orientation === "horizontal" ? "-ml-2" : "-mt-2 flex-col",
            className,
          )}
          {...props}
        >
          {children}
        </div>
      </div>
    )
  },
)

CarouselContent.displayName = "CarouselContent"

type CarouselItemProps = React.HTMLAttributes<HTMLDivElement>

const CarouselItem = React.forwardRef<HTMLDivElement, CarouselItemProps>(
  ({ className, ...props }, ref) => {
    const { orientation } = useCarousel()
    return (
      <div
        ref={ref}
        role="group"
        className={cn(
          "relative min-w-0 shrink-0 grow-0 basis-full p-2",
          orientation === "horizontal" ? "" : "",
          className,
        )}
        {...props}
      />
    )
  },
)

CarouselItem.displayName = "CarouselItem"

type CarouselControlProps = React.ButtonHTMLAttributes<HTMLButtonElement>

function CarouselPrevious({ className, ...props }: CarouselControlProps) {
  const { api, orientation } = useCarousel()

  return (
    <button
      type="button"
      aria-label="Previous slide"
      data-orientation={orientation}
      className={cn(
        "absolute z-10 flex h-12 w-12 items-center justify-center rounded-full bg-black/50 text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none",
        orientation === "horizontal"
          ? "top-1/2 left-4 -translate-y-1/2"
          : "top-4 left-1/2 -translate-x-1/2",
        className,
      )}
      onClick={() => api?.scrollPrev()}
      {...props}
    >
      <span aria-hidden>‹</span>
    </button>
  )
}

function CarouselNext({ className, ...props }: CarouselControlProps) {
  const { api, orientation } = useCarousel()

  return (
    <button
      type="button"
      aria-label="Next slide"
      data-orientation={orientation}
      className={cn(
        "absolute z-10 flex h-12 w-12 items-center justify-center rounded-full bg-black/50 text-white transition hover:bg-black/70 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none",
        orientation === "horizontal"
          ? "top-1/2 right-4 -translate-y-1/2"
          : "bottom-4 left-1/2 -translate-x-1/2",
        className,
      )}
      onClick={() => api?.scrollNext()}
      {...props}
    >
      <span aria-hidden>›</span>
    </button>
  )
}

export type { CarouselApi }
export {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
}
