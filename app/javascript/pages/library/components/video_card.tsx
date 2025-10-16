import { useMemo, useRef, useState } from "react"
import VimeoPlayer, { type VimeoPlayerHandle } from "./player/vimeo_player"

interface VideoCardProps {
  session: LibrarySessionPayload
  showProgress?: boolean
}

interface LibrarySessionPayload {
  id: number
  title: string
  description: string
  categories: LibraryCategoryPayload[]
  padding: number
  vimeoId: string
  vimeoHash?: string
  playerSrc: string
  downloadPath: string
  position: number
  watchHistoryPath: string
  watch?: LibraryWatchPayload | null
}

interface LibraryCategoryPayload {
  id: number
  name: string
  slug: string
}

interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

function formatTimeRemaining(
  playedSeconds: number,
  durationSeconds?: number | null,
): string {
  if (!durationSeconds) return ""

  const remaining = Math.max(0, durationSeconds - playedSeconds)
  const hours = Math.floor(remaining / 3600)
  const minutes = Math.floor((remaining % 3600) / 60)

  if (hours > 0) {
    return `${hours}h ${minutes}m left`
  }
  return `${minutes}m left`
}

export default function VideoCard({
  session,
  showProgress = false,
}: VideoCardProps) {
  const playerRef = useRef<VimeoPlayerHandle>(null)
  const [watchOverride, setWatchOverride] =
    useState<LibraryWatchPayload | null>(session.watch ?? null)

  const progress = (watchOverride ?? session.watch)?.playedSeconds ?? 0
  const duration = (watchOverride ?? session.watch)?.durationSeconds ?? 0
  const progressPercentage = duration > 0 ? (progress / duration) * 100 : 0
  const timeRemaining = useMemo(
    () => (showProgress ? formatTimeRemaining(progress, duration) : ""),
    [showProgress, progress, duration],
  )

  const handleTitleClick = () => {
    playerRef.current?.enterFullscreen()
  }

  return (
    <article
      id={`session-${session.id}`}
      className="relative flex w-[var(--shelf-card-w,21.5vw)] shrink-0 flex-col gap-[0.4vw] p-[4px]"
    >
      <div
        className="group flex flex-col gap-[0.4vw]"
        onMouseEnter={() => playerRef.current?.startPreview()}
        onMouseLeave={() => playerRef.current?.stopPreview()}
        onFocusCapture={() => playerRef.current?.startPreview()}
        onBlurCapture={() => playerRef.current?.stopPreview()}
      >
        <div className="relative order-1 aspect-[16/9] w-full rounded-[0.2vw] shadow-[0_0_0_0px_transparent] transition-shadow duration-150 group-hover:shadow-[0_0_0_1px_transparent,0_0_0_3px_#00ADEF]">
          <div className="absolute inset-0 overflow-hidden rounded-[0.2vw]">
            <VimeoPlayer
              ref={playerRef}
              session={session}
              watchOverride={watchOverride}
              onWatchUpdate={setWatchOverride}
            />
          </div>
          {showProgress && progressPercentage > 0 && (
            <div className="absolute right-0 bottom-0 left-0 h-[0.3vw] bg-gray-600">
              <div
                className="h-full bg-[#00ADEF]"
                style={{
                  width: `${Math.min(progressPercentage, 100)}%`,
                }}
              />
            </div>
          )}
        </div>

        <button
          type="button"
          onClick={handleTitleClick}
          className="peer order-2 flex cursor-pointer flex-col text-left select-none [--hover-filter:brightness(1)] [--hover-size:0]"
        >
          <h3 className="text-[clamp(0.875rem,0.875vw,1.125rem)] leading-tight font-medium text-white capitalize">
            {session.title}
          </h3>
          {timeRemaining && (
            <p className="mt-[0.2vw] text-[clamp(0.75rem,0.9vw,0.9375rem)] leading-tight text-gray-400">
              {timeRemaining}
            </p>
          )}
        </button>
      </div>
    </article>
  )
}
