import { cn } from "@/lib/utils"

interface IndicatorsProps {
  current: number
  total: number
  isReady: boolean
  goTo: (index: number) => void
  onInteract?: () => void
}

export function Indicators({
  current,
  total,
  isReady,
  goTo,
  onInteract,
}: IndicatorsProps) {
  return (
    <nav aria-label="Featured slides" className="pt-2 sm:pt-1 md:pt-0">
      <ol
        className={cn(
          "relative z-0 mt-0 flex items-center justify-center gap-0 transition-opacity duration-250 md:mt-3 lg:mt-5",
          isReady ? "opacity-100" : "opacity-0",
        )}
      >
        {Array.from({ length: total }).map((_, index) => {
          const isActive = index === current
          return (
            <li key={index} className="list-none">
              <button
                type="button"
                aria-label={`Go to slide ${index + 1}`}
                aria-current={isActive ? "page" : undefined}
                onClick={() => {
                  onInteract?.()
                  goTo(index)
                }}
                className="group flex size-6 items-center justify-center ring-0! ring-offset-0! outline-none! hover:ring-0! hover:ring-offset-0! hover:outline-none! focus:ring-0! focus:ring-offset-0! focus:outline-none! focus-visible:ring-2! focus-visible:ring-[#00ADEF]! focus-visible:ring-offset-2! focus-visible:ring-offset-transparent! focus-visible:outline-none! md:size-8 dark:focus-visible:ring-[#00ADEF]!"
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
            </li>
          )
        })}
      </ol>
    </nav>
  )
}
