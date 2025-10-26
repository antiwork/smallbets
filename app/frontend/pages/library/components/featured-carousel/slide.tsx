import { Button } from "@/components/ui/button"
import { cn, formatHoursMinutesFromSeconds } from "@/lib/utils"
import { useState } from "react"
import type { LibrarySessionPayload } from "../../types"
import type { DragBindings, DragState } from "./hooks"

function formatDuration(totalSeconds: number): string {
  return formatHoursMinutesFromSeconds(totalSeconds)
}

export interface SlideProps {
  session: LibrarySessionPayload
  imageSrc?: string | null
  isCurrent: boolean
  isPrevious: boolean
  isNext: boolean
  drag: { bindings: DragBindings; state: DragState }
  onWatch: (id: string | number) => void
}

export function Slide({
  session,
  imageSrc,
  isCurrent,
  isPrevious,
  isNext,
  drag,
  onWatch,
}: SlideProps) {
  const [isImageError, setIsImageError] = useState(false)
  const { dragOffset, isDragging } = drag.state
  const durationSeconds = session.watch?.durationSeconds ?? null
  const durationLabel =
    typeof durationSeconds === "number" && durationSeconds > 0
      ? formatDuration(durationSeconds)
      : null

  return (
    <article
      key={session.id}
      role="group"
      aria-roledescription="slide"
      aria-label={`${session.title} — by ${session.creator}`}
      aria-hidden={!isCurrent}
      tabIndex={isCurrent ? 0 : -1}
      style={
        isCurrent
          ? {
              transform:
                dragOffset !== 0 ? `translateX(${dragOffset}px)` : undefined,
              transition: isDragging ? "none" : "all 500ms",
              touchAction: "none",
            }
          : undefined
      }
      className={cn(
        "bg-muted absolute inset-0 overflow-hidden rounded-3xl shadow-2xl transition-all duration-250",
        "opacity-0",
        isCurrent && "z-30 scale-100 opacity-100 shadow-black/40",
        isPrevious &&
          "z-20 -translate-x-[6%] scale-100 opacity-0 shadow-none md:-translate-x-[18%] md:scale-[0.90] md:opacity-70 md:shadow-2xl",
        isNext &&
          "z-20 translate-x-[6%] scale-100 opacity-0 shadow-none md:translate-x-[18%] md:scale-[0.90] md:opacity-70 md:shadow-2xl",
        !isCurrent && !isPrevious && !isNext && "pointer-events-none opacity-0",
        isCurrent && "cursor-grab active:cursor-grabbing",
        isCurrent &&
          "!shadow-none hover:shadow-[0_0_0_1px_transparent,0_0_0_3px_#00ADEF]! focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:ring-offset-4 focus-visible:ring-offset-transparent focus-visible:outline-none",
      )}
      onPointerDownCapture={
        isCurrent ? drag.bindings.onPointerDownCapture : undefined
      }
      onPointerMoveCapture={
        isCurrent ? drag.bindings.onPointerMoveCapture : undefined
      }
      onPointerUpCapture={
        isCurrent ? drag.bindings.onPointerUpCapture : undefined
      }
      onPointerCancelCapture={
        isCurrent ? drag.bindings.onPointerCancelCapture : undefined
      }
      onClickCapture={isCurrent ? drag.bindings.onClickCapture : undefined}
    >
      <div className="relative flex h-full flex-col justify-end">
        {imageSrc && !isImageError ? (
          <picture className="absolute inset-0 z-0 h-full w-full">
            <source type="image/webp" srcSet={imageSrc} />
            <img
              src={imageSrc}
              alt=""
              loading="lazy"
              decoding="async"
              className="h-full w-full object-cover"
              draggable="false"
              onError={() => setIsImageError(true)}
            />
          </picture>
        ) : (
          <div className="absolute inset-0 z-0 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800" />
        )}

        <div
          aria-hidden={!isCurrent}
          className={cn(
            "relative z-20 flex flex-col gap-3 p-5 pb-2 text-white transition-all duration-500 sm:gap-4 sm:p-10 sm:pb-10",
            isCurrent
              ? "translate-y-0 opacity-100"
              : "pointer-events-none translate-y-6 opacity-0",
          )}
        >
          <h3 className="sr-only">{session.title}</h3>

          <div className="flex flex-wrap items-center gap-3">
            <Button
              size="lg"
              data-no-drag="true"
              className="hidden items-center gap-3 rounded-lg bg-white! px-8 py-5 text-base font-semibold text-black shadow-lg transition hover:bg-white/90 sm:inline-flex"
              onClick={() => onWatch(session.id)}
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
            <div className="flex items-center justify-center gap-2">
              <span
                className="hidden text-xl font-bold sm:inline"
                aria-hidden="true"
              >
                ·
              </span>
              <span className="text-sm font-medium text-white">
                {session.creator}
              </span>
              {durationLabel && (
                <>
                  <span aria-hidden="true" className="text-xl font-bold">
                    ·
                  </span>
                  <span className="text-sm font-medium text-white">
                    {durationLabel}
                  </span>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
      {isCurrent && (
        <button
          type="button"
          aria-label={`Watch ${session.title}`}
          className="absolute inset-0 z-30 cursor-pointer bg-transparent focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00ADEF] sm:hidden"
          onClick={() => onWatch(session.id)}
        >
          <span className="sr-only">Watch {session.title}</span>
        </button>
      )}
    </article>
  )
}
