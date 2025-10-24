import VideoCard from "../video_card"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"
import type { CSSProperties } from "react"

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
  if (sessions.length === 0) {
    return (
      <div className="text-muted-foreground mx-auto max-w-6xl px-6 text-center text-base">
        No sessions found. Try a different search.
      </div>
    )
  }

  return (
    <div className="mx-auto w-full max-w-7xl px-6">
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {sessions.map((session) => (
          <div
            key={session.id}
            className="flex"
            style={
              {
                // Ensure VideoCard takes full width within the grid cell
                // while preserving its internal responsive sizing.
                "--shelf-card-w": "100%",
              } as CSSProperties
            }
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
  )
}
