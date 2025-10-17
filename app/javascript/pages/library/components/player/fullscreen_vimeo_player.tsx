import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { router } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

import { usePage } from "@inertiajs/react"
import {
  postWatchHistory,
  type WatchPayload,
  type WatchRequestOptions,
} from "./watch_history"
import type { LibrarySessionPayload } from "../../types"
import type { DownloadEntry } from "./types"

interface FullscreenVimeoPlayerProps {
  session: LibrarySessionPayload
  backIcon?: string
}

export default function FullscreenVimeoPlayer({
  session,
  backIcon,
}: FullscreenVimeoPlayerProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null)
  const resumeAtRef = useRef<number | null>(
    session.watch?.playedSeconds ?? null,
  )
  const progressRef = useRef<WatchPayload | null>(session.watch ?? null)
  const [, setStatus] = useState<"idle" | "saving" | "error">("idle")
  const watchPath = session.watchHistoryPath

  const PROGRESS_THROTTLE_MS = 10_000

  interface ProgressThrottler {
    queue: (payload: WatchPayload) => void
    flush: (payload?: WatchPayload, options?: WatchRequestOptions) => void
    cancel: () => void
  }

  const throttler = useMemo<ProgressThrottler>(() => {
    let timer: number | null = null
    let pending: WatchPayload | null = null

    function clearTimer(): void {
      if (timer === null) return
      window.clearTimeout(timer)
      timer = null
    }

    function persist(payload: WatchPayload, options?: WatchRequestOptions) {
      setStatus("saving")
      void postWatchHistory(watchPath, payload, options).then((result) => {
        setStatus(result.ok ? "idle" : "error")
      })
    }

    return {
      queue(payload) {
        pending = payload
        if (timer !== null) return
        timer = window.setTimeout(() => {
          if (pending) persist(pending)
          pending = null
          timer = null
        }, PROGRESS_THROTTLE_MS)
      },
      flush(payload, options) {
        const next = payload ?? pending
        pending = null
        clearTimer()
        if (!next) return
        persist(next, options)
      },
      cancel() {
        pending = null
        clearTimer()
      },
    }
  }, [watchPath])

  const playerSrc = useMemo(() => {
    try {
      const url = new URL(session.playerSrc)
      url.searchParams.set("controls", "1")
      url.searchParams.set("fullscreen", "1")
      url.searchParams.set("autoplay", "1")
      url.searchParams.set("muted", "0")
      return url.toString()
    } catch (_error) {
      return session.playerSrc
    }
  }, [session.playerSrc])

  // Basic Vimeo postMessage helpers
  const postToVimeo = useCallback((payload: Record<string, unknown>) => {
    try {
      frameRef.current?.contentWindow?.postMessage(payload, "*")
    } catch {}
  }, [])

  const subscribeToEvents = useCallback(() => {
    const events = ["play", "pause", "timeupdate", "seeked", "ended"] as const
    events.forEach((event) => {
      postToVimeo({ method: "addEventListener", value: event })
    })
  }, [postToVimeo])

  useEffect(() => {
    document.body.style.overflow = "hidden"

    const flushWithKeepalive = () => {
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
    }

    const handleKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        flushWithKeepalive()
        router.visit("/library", { replace: true, preserveScroll: true })
      }
    }

    const handleMessage = (event: MessageEvent) => {
      if (event.source !== frameRef.current?.contentWindow) return
      const data =
        typeof event.data === "string" ? safelyParse(event.data) : event.data
      if (!data || typeof data !== "object" || !("event" in data)) return

      const now = new Date().toISOString()

      switch ((data as any).event) {
        case "ready": {
          subscribeToEvents()
          const resumeAt = resumeAtRef.current
          if (resumeAt != null) {
            postToVimeo({ method: "setCurrentTime", value: resumeAt })
          }
          postToVimeo({ method: "play" })
          break
        }
        case "timeupdate": {
          const seconds = Number((data as any).data?.seconds ?? 0)
          const duration = Number((data as any).data?.duration ?? 0)
          const next: WatchPayload = {
            playedSeconds: seconds,
            durationSeconds: duration,
            completed: false,
            lastWatchedAt: now,
          }
          progressRef.current = next
          throttler.queue(next)
          break
        }
        case "seeked": {
          const seconds = Number((data as any).data?.seconds ?? 0)
          const duration = Number((data as any).data?.duration ?? 0)
          const next: WatchPayload = {
            playedSeconds: seconds,
            durationSeconds: duration,
            completed: false,
            lastWatchedAt: now,
          }
          progressRef.current = next
          throttler.flush(next)
          break
        }
        case "pause": {
          const seconds = Number((data as any).data?.seconds ?? 0)
          const duration = Number((data as any).data?.duration ?? 0)
          const next: WatchPayload = {
            playedSeconds: seconds,
            durationSeconds: duration,
            completed: false,
            lastWatchedAt: now,
          }
          progressRef.current = next
          throttler.flush(next)
          break
        }
        case "ended": {
          const seconds = Number((data as any).data?.seconds ?? 0)
          const duration = Number((data as any).data?.duration ?? seconds)
          const final = duration > 0 ? duration : seconds
          const next: WatchPayload = {
            playedSeconds: final,
            durationSeconds: final,
            completed: true,
            lastWatchedAt: now,
          }
          progressRef.current = next
          throttler.flush(next)
          break
        }
        default:
          break
      }
    }

    const handleVisibilityChange = () => {
      if (document.visibilityState === "hidden") flushWithKeepalive()
    }
    const handlePageHide = () => flushWithKeepalive()
    const handleBeforeUnload = () => flushWithKeepalive()

    window.addEventListener("message", handleMessage)
    document.addEventListener("keydown", handleKey)
    document.addEventListener("visibilitychange", handleVisibilityChange)
    window.addEventListener("pagehide", handlePageHide)
    window.addEventListener("beforeunload", handleBeforeUnload)

    return () => {
      document.body.style.overflow = ""
      document.removeEventListener("keydown", handleKey)
      document.removeEventListener("visibilitychange", handleVisibilityChange)
      window.removeEventListener("pagehide", handlePageHide)
      window.removeEventListener("beforeunload", handleBeforeUnload)
      window.removeEventListener("message", handleMessage)
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
      throttler.cancel()
    }
  }, [postToVimeo, throttler, subscribeToEvents])

  useEffect(() => {
    // Kick a ping to trigger ready flow quickly
    postToVimeo({ method: "ping" })
  }, [postToVimeo])

  function safelyParse(s: string): unknown {
    try {
      return JSON.parse(s)
    } catch {
      return null
    }
  }

  return (
    <div
      className="fixed inset-0 z-[999] flex flex-col bg-black"
      style={{ ["--bar-h" as any]: "72px" }}
    >
      <button
        type="button"
        aria-label="Go Back"
        onClick={() => {
          throttler.flush(progressRef.current ?? undefined, { keepalive: true })
          router.visit("/library", { replace: true, preserveScroll: true })
        }}
        className="absolute top-4 left-4 z-[1000] flex size-10 items-center justify-center rounded-full bg-black/60! text-white transition-opacity duration-250 ease-out hover:bg-black/80!"
      >
        <span
          aria-hidden="true"
          className="inline-block size-5 bg-white"
          style={{
            maskImage: `url(${backIcon})`,
            WebkitMaskImage: `url(${backIcon})`,
            maskRepeat: "no-repeat",
            WebkitMaskRepeat: "no-repeat",
            maskPosition: "center",
            WebkitMaskPosition: "center",
            maskSize: "contain",
            WebkitMaskSize: "contain",
          }}
        />
      </button>
      <div className="flex flex-1 items-center justify-center">
        <iframe
          ref={frameRef}
          title={session.title}
          src={playerSrc}
          className="vimeo-embed h-auto max-h-[calc(100vh-var(--bar-h))] w-[100vw]"
          style={{ aspectRatio: "16 / 9" }}
          allow="fullscreen; autoplay; picture-in-picture; clipboard-write"
          loading="lazy"
          allowFullScreen={true}
          referrerPolicy="strict-origin-when-cross-origin"
        />
      </div>
      <div className="flex h-[var(--bar-h)] items-center justify-between border-t border-white/10 bg-black/95 px-4 pb-[calc(env(safe-area-inset-bottom))] text-white md:px-6">
        <div className="min-w-0 pr-3">
          <div className="truncate text-lg font-medium">{session.title}</div>
          <div className="truncate text-sm text-gray-400">
            {session.creator}
          </div>
        </div>
        <DownloadMenu
          vimeoId={session.vimeoId}
          downloadPath={session.downloadPath}
          title={session.title}
        />
      </div>
    </div>
  )
}

interface DownloadMenuProps {
  vimeoId: string
  downloadPath?: string
  title?: string
}

function DownloadMenu({ vimeoId, downloadPath, title }: DownloadMenuProps) {
  interface InertiaPageProps {
    assets?: { downloadIcon?: string }
    [key: string]: unknown
  }
  const { props } = usePage<InertiaPageProps>()
  const downloadIconSrc = props.assets?.downloadIcon ?? "/assets/download.svg"

  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [entries, setEntries] = useState<DownloadEntry[]>([])
  const portalRef = useRef<HTMLDivElement | null>(null)

  const isDownloadEntry = useCallback((d: unknown): d is DownloadEntry => {
    return (
      !!d &&
      typeof d === "object" &&
      ("quality" in (d as Record<string, unknown>) ||
        "link" in (d as Record<string, unknown>))
    )
  }, [])

  useEffect(() => {
    if (entries.length > 0 || loading || error) return
    setLoading(true)
    fetch(`/library/downloads/${vimeoId}`, {
      headers: { Accept: "application/json" },
    })
      .then((r) =>
        r.ok ? r.json() : Promise.reject(new Error(String(r.status))),
      )
      .then((json: unknown) => {
        const list = Array.isArray(json)
          ? (json.filter(isDownloadEntry) as DownloadEntry[])
          : []
        setEntries(list)
        setError(list.length === 0 ? "No options" : null)
      })
      .catch(() => setError("Unable to load"))
      .finally(() => setLoading(false))
  }, [vimeoId, entries.length, loading, error, isDownloadEntry])

  function hrefFor(download: DownloadEntry): string | null {
    if (download.quality) {
      const url = new URL(
        `/library/download/${vimeoId}`,
        window.location.origin,
      )
      url.searchParams.set("quality", download.quality)
      return url.toString()
    }
    return download.link || downloadPath || null
  }

  function qualityLabel(download: DownloadEntry): string {
    if (download.quality) return String(download.quality).toUpperCase()
    if (download.type) return String(download.type).toUpperCase()
    return title ? `Download (${title})` : "Download"
  }

  function details(download: DownloadEntry): string {
    const parts: string[] = []
    const w = download.width
    const h = download.height
    if (w && h) parts.push(`${w}×${h}`)
    const short = download.size_short
    const size = Number(download.size)
    if (short) parts.push(short)
    else if (Number.isFinite(size) && size > 0) {
      const units = ["B", "KB", "MB", "GB", "TB"]
      let value = size
      let i = 0
      while (value >= 1024 && i < units.length - 1) {
        value /= 1024
        i += 1
      }
      parts.push(`${value.toFixed(value >= 10 ? 0 : 1)} ${units[i]}`)
    }
    return parts.join(" • ")
  }

  return (
    <div className="relative z-50 shrink-0" ref={portalRef}>
      <DropdownMenu modal={false} open={open} onOpenChange={setOpen}>
        <DropdownMenuTrigger asChild>
          <Button variant="secondary" className="border border-[#555]">
            <span
              aria-hidden="true"
              className="mr-1 inline-block size-3.5 bg-white"
              style={{
                maskImage: `url(${downloadIconSrc})`,
                WebkitMaskImage: `url(${downloadIconSrc})`,
                maskRepeat: "no-repeat",
                WebkitMaskRepeat: "no-repeat",
                maskPosition: "center",
                WebkitMaskPosition: "center",
                maskSize: "contain",
                WebkitMaskSize: "contain",
              }}
            />
            Download
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent
          container={portalRef.current}
          side="top"
          align="end"
          sideOffset={8}
          className="w-64 border border-white/10 bg-black/95 text-white shadow-lg"
        >
          {loading && (
            <div className="px-2 py-1.5 text-sm select-none">Loading…</div>
          )}
          {error && (
            <a
              href={downloadPath || undefined}
              target="_blank"
              rel="nofollow noopener"
              className="block px-2 py-1.5 text-sm"
            >
              Error loading download options
            </a>
          )}
          {!loading &&
            !error &&
            entries.map((d, idx) => {
              const href = hrefFor(d)
              return (
                <DropdownMenuItem
                  key={idx}
                  onSelect={(e) => {
                    e.preventDefault()
                    if (!href) return
                    try {
                      window.open(href, "_blank", "noopener,noreferrer")
                    } catch {}
                    setOpen(false)
                  }}
                >
                  <div className="flex w-full cursor-pointer items-center justify-between gap-2">
                    <span className="text-sm">{qualityLabel(d)}</span>
                    <span className="text-muted-foreground text-xs">
                      {details(d)}
                    </span>
                  </div>
                </DropdownMenuItem>
              )
            })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}
