import ContinueWatchingShelf from "./shelves/continue_watching_shelf"
import type { LibrarySessionPayload } from "../types"

interface LibraryHeroProps {
  continueWatching: LibrarySessionPayload[]
  backIcon?: string
}

export default function LibraryHero({
  continueWatching,
  backIcon,
}: LibraryHeroProps) {
  return (
    <section className="pl-3">
      <ContinueWatchingShelf sessions={continueWatching} backIcon={backIcon} />
    </section>
  )
}
