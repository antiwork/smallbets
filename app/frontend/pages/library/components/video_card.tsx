import { memo, useEffect, useMemo, useRef, useState } from "react"
import { useHoverPreviewGuard } from "./hooks/use-hover-preview-guard"
import { useIntersectionStop } from "./hooks/use-intersection-stop"
import {
  VimeoPlayer,
  type VimeoPlayerHandle,
} from "@/pages/library/components/player"
import { router } from "@inertiajs/react"
import { formatHoursMinutesFromSeconds } from "@/lib/utils"
import type {
  LibrarySessionPayload,
  LibraryWatchPayload,
  VimeoThumbnailPayload,
} from "../types"

interface VideoCardProps {
  session: LibrarySessionPayload
  thumbnail?: VimeoThumbnailPayload
  showProgress?: boolean
  backIcon?: string
  persistPreview?: boolean
  imageLoading?: "eager" | "lazy"
  fetchPriority?: "auto" | "high" | "low"
}

function formatTimeRemaining(
  playedSeconds: number,
  durationSeconds?: number | null,
): string {
  if (!durationSeconds) return ""
  const remaining = Math.max(0, durationSeconds - playedSeconds)
  return `${formatHoursMinutesFromSeconds(remaining)} left`
}

function VideoCard({
  session,
  thumbnail,
  showProgress = false,
  backIcon,
  persistPreview = false,
  imageLoading = "lazy",
  fetchPriority = "auto",
}: VideoCardProps) {
  const [stickyThumbnail, setStickyThumbnail] = useState<
    VimeoThumbnailPayload | undefined
  >(thumbnail)
  const playerRef = useRef<VimeoPlayerHandle>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [shouldStartOnVisible, setShouldStartOnVisible] = useState(false)
  const [iframeVisible, setIframeVisible] = useState(false)
  const [iframeReady, setIframeReady] = useState(false)
  const hoverMoveStartedRef = useRef(false)

  const [watchOverride, setWatchOverride] =
    useState<LibraryWatchPayload | null>(session.watch ?? null)

  const progress = (watchOverride ?? session.watch)?.playedSeconds ?? 0
  const duration = (watchOverride ?? session.watch)?.durationSeconds ?? 0
  const progressPercentage = duration > 0 ? (progress / duration) * 100 : 0
  const timeRemaining = useMemo(
    () => (showProgress ? formatTimeRemaining(progress, duration) : ""),
    [showProgress, progress, duration],
  )

  useEffect(() => {
    if (thumbnail) setStickyThumbnail(thumbnail)
  }, [thumbnail])

  const activeThumbnail = stickyThumbnail ?? thumbnail

  useEffect(() => {
    if (!iframeVisible) return
    if (!shouldStartOnVisible) return
    playerRef.current?.startPreview()
    setShouldStartOnVisible(false)
  }, [iframeVisible, shouldStartOnVisible])

  useIntersectionStop({
    containerRef,
    onOutOfView: () => {
      hoverMoveStartedRef.current = false
      disarm()
      playerRef.current?.stopPreview()
      setIframeVisible(false)
      setIframeReady(false)
    },
  })

  const { arm, disarm } = useHoverPreviewGuard({
    containerRef,
    onStop: () => {
      hoverMoveStartedRef.current = false
      playerRef.current?.stopPreview()
    },
  })

  function isDataSaverEnabled(): boolean {
    try {
      const conn = (
        navigator as unknown as { connection?: { saveData?: boolean } }
      ).connection
      return Boolean(conn && conn.saveData)
    } catch (_e) {
      return false
    }
  }

  function supportsHover(): boolean {
    try {
      if (typeof window === "undefined" || !("matchMedia" in window))
        return true
      return window.matchMedia("(hover: hover) and (pointer: fine)").matches
    } catch (_e) {
      return true
    }
  }

  const prefetchWatchPage = () => {
    if (isDataSaverEnabled()) return
    const href = `/library/${session.id}`
    const anyRouter = router as unknown as {
      prefetch?: (
        url: string,
        visit?: Record<string, unknown>,
        opts?: { cacheFor?: string | number; cacheTags?: string | string[] },
      ) => void
    }
    anyRouter.prefetch?.(
      href,
      { method: "get", preserveScroll: true },
      { cacheFor: "30s", cacheTags: "library-watch" },
    )
  }

  const handleTitleClick = () => {
    try {
      const current = playerRef.current?.getCurrentWatch?.()
      if (current && (current.playedSeconds ?? 0) > 0) {
        const key = `library:preview:${session.id}`
        sessionStorage.setItem(key, JSON.stringify(current))
      }
    } catch (_e) {
      // ignore storage errors
    }
    router.visit(`/library/${session.id}`, {
      preserveScroll: true,
    })
  }

  return (
    <article
      id={`session-${session.id}`}
      className="relative flex w-full shrink-0 flex-col gap-[0.4vw] p-[4px] select-none"
    >
      <div
        ref={containerRef}
        className="group relative flex flex-col gap-3"
        onPointerEnter={() => {
          if (!supportsHover()) return
          if (isDataSaverEnabled()) return
          hoverMoveStartedRef.current = false
          prefetchWatchPage()
        }}
        onPointerMove={() => {
          if (!supportsHover()) return
          // Ignore early synthetic moves during initial render/reflow
          const now = performance.now?.() ?? Date.now()
          // Safari/iOS may send movementX=0; require actual pageX/pageY change from element entry
          // Use a short debounce from mount to avoid triggers before thumbs are visible
          if (
            window.__sb_page_boot_ts &&
            now - window.__sb_page_boot_ts < 300
          )
            return
          if (hoverMoveStartedRef.current) return
          hoverMoveStartedRef.current = true
          if (!iframeVisible) setIframeVisible(true)
          arm()
          setShouldStartOnVisible(true)
        }}
        onPointerLeave={() => {
          hoverMoveStartedRef.current = false
          disarm()
          playerRef.current?.stopPreview()
          setIframeVisible(false)
          setIframeReady(false)
        }}
        onPointerCancel={() => {
          hoverMoveStartedRef.current = false
          disarm()
          playerRef.current?.stopPreview()
          setIframeVisible(false)
          setIframeReady(false)
        }}
      >
        <figure className="relative order-1 aspect-[16/9] w-full overflow-hidden rounded shadow-[0_0_0_0px_transparent] transition-shadow duration-150 select-none group-hover:shadow-[0_0_0_1px_transparent,0_0_0_3px_#00ADEF]">
          {activeThumbnail ? (
            <picture className="absolute inset-0 block h-full w-full">
              <source
                srcSet={activeThumbnail.srcset}
                sizes="(min-width: 768px) 33vw, 100vw"
              />
              <img
                src={activeThumbnail.src}
                alt=""
                decoding="async"
                loading={imageLoading}
                fetchPriority={fetchPriority}
                draggable={false}
                width={activeThumbnail.width}
                height={activeThumbnail.height}
                className={`absolute inset-0 size-full object-cover transition-opacity duration-300 ${iframeVisible && iframeReady ? "opacity-0" : "opacity-100"}`}
              />
            </picture>
          ) : (
            <div
              aria-hidden
              className="absolute inset-0 z-0 flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 opacity-80 motion-safe:animate-[pulse_8s_ease-in-out_infinite]"
            />
          )}
          <div className="absolute inset-0 overflow-hidden">
            {iframeVisible ? (
              <div
                className={`absolute inset-0 transition-opacity duration-150 ${iframeReady ? "opacity-100" : "opacity-0"}`}
              >
                <VimeoPlayer
                  ref={playerRef}
                  session={session}
                  watchOverride={watchOverride}
                  onWatchUpdate={setWatchOverride}
                  backIcon={backIcon}
                  persistPreview={persistPreview}
                  onReady={() => setIframeReady(true)}
                />
              </div>
            ) : null}
          </div>
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,rgba(0,0,0,0.4)_100%)] opacity-100 transition-opacity duration-300 group-hover:opacity-0" />
          {showProgress && progressPercentage > 0 && (
            <div
              className="absolute right-2 bottom-1 left-2 h-[5px] overflow-hidden rounded-full bg-gray-600/70"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.min(progressPercentage, 100)}
              aria-label="Watch progress"
            >
              <div
                className="h-full rounded-full bg-[#00ADEF]"
                style={{
                  width: `${Math.min(progressPercentage, 100)}%`,
                }}
              />
            </div>
          )}
          {timeRemaining && (
            <figcaption className="sr-only">{timeRemaining}</figcaption>
          )}
        </figure>

        <div className="peer order-2 flex flex-col gap-0.5 text-left select-none [--hover-filter:brightness(1)] [--hover-size:0]">
          {timeRemaining && (
            <p className="library-muted-light text-xs leading-tight">
              {timeRemaining}
            </p>
          )}
          <h3 className="text-foreground text-sm font-medium capitalize">
            {session.title}
          </h3>
        </div>
        <a
          href={`/library/${session.id}`}
          aria-label={`Open ${session.title}`}
          onMouseDown={prefetchWatchPage}
          onClick={(e) => {
            e.preventDefault()
            handleTitleClick()
          }}
          className="absolute inset-0 z-[1] cursor-pointer rounded bg-transparent select-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00ADEF]"
        />
      </div>
    </article>
  )
}

function arePropsEqual(prev: VideoCardProps, next: VideoCardProps): boolean {
  if (prev.session !== next.session) return false
  if (prev.showProgress !== next.showProgress) return false
  if (prev.persistPreview !== next.persistPreview) return false
  if (prev.backIcon !== next.backIcon) return false
  const prevThumb = prev.thumbnail
  const nextThumb = next.thumbnail
  if (!prevThumb && !nextThumb) return true
  if (!prevThumb || !nextThumb) return false
  return (
    prevThumb.src === nextThumb.src &&
    prevThumb.width === nextThumb.width &&
    prevThumb.height === nextThumb.height &&
    prevThumb.srcset === nextThumb.srcset
  )
}

export default memo(VideoCard, arePropsEqual)
