import VimeoPlayer from "./player/vimeo_player"

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
  const progress = session.watch?.playedSeconds ?? 0
  const duration = session.watch?.durationSeconds ?? 0
  const progressPercentage = duration > 0 ? (progress / duration) * 100 : 0
  const timeRemaining = showProgress
    ? formatTimeRemaining(progress, duration)
    : ""

  return (
    <article
      id={`session-${session.id}`}
      className="group relative flex w-[21.5vw] shrink-0 flex-col gap-[0.4vw]"
    >
      <div className="relative w-full overflow-hidden rounded-[0.2vw] pb-[12.1vw]">
        <div className="absolute inset-0">
          <VimeoPlayer session={session} />
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

      <div className="flex flex-col">
        <h3 className="text-[1.1vw] leading-[1.3w] font-medium text-white capitalize">
          {session.title}
        </h3>
        {timeRemaining && (
          <p className="mt-[0.2vw] text-[0.9vw] leading-[1.1vw] text-gray-400">
            {timeRemaining}
          </p>
        )}
      </div>
    </article>
  )
}
