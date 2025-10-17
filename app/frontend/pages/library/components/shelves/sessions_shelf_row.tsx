import VideoCard from "../video_card"
import type { LibrarySessionPayload } from "../../types"

export function SessionsShelfRow({
  sessions,
  backIcon,
  title,
  showProgress = false,
  persistPreview = false,
}: {
  sessions: LibrarySessionPayload[]
  backIcon?: string
  title?: string
  showProgress?: boolean
  persistPreview?: boolean
}) {
  if (sessions.length === 0) return null

  return (
    <div className="flex flex-col gap-[1vw]">
      {title ? (
        <h2 className="pl-1 text-xl leading-tight font-medium tracking-wider text-white capitalize select-none">
          {title}
        </h2>
      ) : null}
      <div className="relative">
        <div className="scrollbar-hide flex gap-[0.8vw] overflow-x-auto overflow-y-visible pr-0 pb-[0.4vw] [--shelf-card-w:calc((100%_-_var(--shelf-gap)_*_(var(--shelf-items)))/(var(--shelf-items)_+_var(--shelf-peek)))] [--shelf-gap:0.8vw] [--shelf-items:2] [--shelf-peek:0.25] md:[--shelf-items:3] lg:[--shelf-items:4] xl:[--shelf-items:5] 2xl:[--shelf-items:6]">
          {sessions.map((session) => (
            <VideoCard
              key={session.id}
              session={session}
              backIcon={backIcon}
              showProgress={showProgress}
              persistPreview={persistPreview}
            />
          ))}
        </div>
      </div>
    </div>
  )
}
