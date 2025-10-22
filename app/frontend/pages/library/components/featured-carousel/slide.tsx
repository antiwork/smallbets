import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"
import type { DragBindings, DragState } from "./hooks"

export interface SlideProps {
  session: LibrarySessionPayload
  thumbnail?: VimeoThumbnailPayload
  isCurrent: boolean
  isPrevious: boolean
  isNext: boolean
  drag: { bindings: DragBindings; state: DragState }
  onWatch: (id: string | number) => void
}

export function Slide({
  session,
  thumbnail,
  isCurrent,
  isPrevious,
  isNext,
  drag,
  onWatch,
}: SlideProps) {
  const { dragOffset, isDragging } = drag.state

  return (
    <article
      key={session.id}
      role="group"
      aria-roledescription="slide"
      aria-label={`${session.title}`}
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
          "z-20 -translate-x-[20%] scale-[0.90] opacity-70 md:-translate-x-[18%]",
        isNext &&
          "z-20 translate-x-[20%] scale-[0.90] opacity-70 md:translate-x-[18%]",
        !isCurrent && !isPrevious && !isNext && "pointer-events-none opacity-0",
        isCurrent && "cursor-grab active:cursor-grabbing",
        isCurrent &&
          "shadow-none! hover:shadow-[0_0_0_1px_transparent,0_0_0_3px_#00ADEF]!",
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
            "relative z-20 flex flex-col gap-3 p-6 pb-8 text-white transition-all duration-500 sm:gap-4 sm:p-10 sm:pb-10",
            isCurrent
              ? "translate-y-0 opacity-100"
              : "pointer-events-none translate-y-6 opacity-0",
          )}
        >
          <div className="max-w-[30ch]">
            <h3 className="mt-2 text-lg leading-tight font-semibold text-balance select-none sm:text-3xl md:text-3xl">
              {session.title}
            </h3>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <Button
              size="lg"
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
          </div>
        </div>
      </div>
      {isCurrent && (
        <button
          type="button"
          aria-label={`Watch ${session.title}`}
          className="absolute inset-0 z-30 cursor-pointer bg-transparent focus:outline-none focus-visible:ring-2 focus-visible:ring-white/60 sm:hidden"
          onClick={() => onWatch(session.id)}
        >
          <span className="sr-only">Watch {session.title}</span>
        </button>
      )}
    </article>
  )
}
