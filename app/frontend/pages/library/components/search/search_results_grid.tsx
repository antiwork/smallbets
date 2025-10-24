import VideoCard from "../video_card"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"

export interface SearchResultsGridProps {
  sessions: LibrarySessionPayload[]
  thumbnails?: Record<string, VimeoThumbnailPayload>
  backIcon?: string
}

export function SearchResultsGrid({
  sessions,
  thumbnails,
  backIcon,
}: SearchResultsGridProps) {
  const resultsCount = sessions.length

  if (resultsCount === 0) {
    return (
      <>
        <div
          className="sr-only"
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          No sessions found. Try a different search.
        </div>
        <div className="text-muted-foreground mx-auto max-w-6xl px-6 pt-4 text-center text-base">
          No sessions found. Try a different search.
        </div>
      </>
    )
  }

  return (
    <>
      <div
        className="sr-only"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        {resultsCount === 1
          ? "1 session found"
          : `${resultsCount} sessions found`}
      </div>
      <div className="mx-auto w-full max-w-7xl px-6 pt-4">
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {sessions.map((session) => (
            <div
              key={session.id}
              className="flex"
              style={{ "--shelf-card-w": "100%" } as React.CSSProperties}
            >
              <VideoCard
                session={session}
                backIcon={backIcon}
                thumbnail={thumbnails?.[session.vimeoId]}
                showProgress={false}
                persistPreview={false}
              />
            </div>
          ))}
        </div>
      </div>
    </>
  )
}
