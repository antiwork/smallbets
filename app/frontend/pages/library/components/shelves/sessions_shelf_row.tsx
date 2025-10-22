import VideoCard from "../video_card"
import type { LibrarySessionPayload, VimeoThumbnailPayload } from "../../types"

export function SessionsShelfRow({
  sessions,
  backIcon,
  title,
  showProgress = false,
  persistPreview = false,
  thumbnails,
  id,
}: {
  sessions: LibrarySessionPayload[]
  backIcon?: string
  title?: string
  showProgress?: boolean
  persistPreview?: boolean
  thumbnails?: Record<string, VimeoThumbnailPayload>
  id?: string
}) {
  if (sessions.length === 0) return null

  const headingId = title
    ? `shelf-${title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "")}`
    : undefined

  return (
    <section
      id={id}
      tabIndex={id ? -1 : undefined}
      className="flex flex-col gap-[1vw]"
      aria-labelledby={headingId}
    >
      {title ? (
        <h2
          id={headingId}
          className="text-foreground pl-1 text-xl leading-tight font-medium tracking-wider capitalize select-none"
        >
          {title}
        </h2>
      ) : null}
      <div className="relative">
        <ul className="scrollbar-hide flex list-none gap-[0.8vw] overflow-x-auto overflow-y-visible pr-0 pb-[0.4vw] pl-0 [--shelf-card-w:calc((100%_-_var(--shelf-gap)_*_(var(--shelf-items)))/(var(--shelf-items)_+_var(--shelf-peek)))] [--shelf-gap:0.8vw] [--shelf-items:2] [--shelf-peek:0.25] md:[--shelf-items:3] lg:[--shelf-items:4] xl:[--shelf-items:5] 2xl:[--shelf-items:6]">
          {sessions.map((session) => (
            <li key={session.id} className="contents list-none">
              <VideoCard
                session={session}
                backIcon={backIcon}
                showProgress={showProgress}
                persistPreview={persistPreview}
                thumbnail={thumbnails?.[session.vimeoId]}
              />
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}
