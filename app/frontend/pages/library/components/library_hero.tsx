import ContinueWatchingShelf from "./shelves/continue_watching_shelf"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../types"

interface LibraryHeroProps {
  continueWatching: LibrarySessionPayload[]
  backIcon?: string
  thumbnails?: Record<string, VimeoThumbnailPayload>
}

export default function LibraryHero({
  continueWatching,
  backIcon,
  thumbnails,
}: LibraryHeroProps) {
  return (
    <ContinueWatchingShelf
      sessions={continueWatching}
      backIcon={backIcon}
      thumbnails={thumbnails}
    />
  )
}
