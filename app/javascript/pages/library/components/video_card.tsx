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
      className="group relative flex shrink-0 flex-col"
      style={{
        width: "21.5vw",
        gap: "0.4vw",
      }}
    >
      <div
        className="relative w-full overflow-hidden"
        style={{
          borderRadius: "0.2vw",
          paddingBottom: "12.1vw",
        }}
      >
        <div className="absolute inset-0">
          <VimeoPlayer session={session} />
        </div>
        {showProgress && progressPercentage > 0 && (
          <div
            className="absolute right-0 bottom-0 left-0 bg-gray-600"
            style={{ height: "0.3vw" }}
          >
            <div
              className="h-full bg-red-600"
              style={{
                width: `${Math.min(progressPercentage, 100)}%`,
              }}
            />
          </div>
        )}
      </div>

      <div className="flex flex-col">
        <h3
          className="font-medium text-white capitalize"
          style={{
            fontSize: "1.1vw",
            lineHeight: "1.3vw",
          }}
        >
          {session.title}
        </h3>
        {timeRemaining && (
          <p
            className="text-gray-400"
            style={{
              fontSize: "0.9vw",
              lineHeight: "1.1vw",
              marginTop: "0.2vw",
            }}
          >
            {timeRemaining}
          </p>
        )}
      </div>
    </article>
  )
}
