import { useCallback, useEffect, useRef, useState } from "react"
import { usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import type { DownloadEntry } from "../types"

const downloadsCache: Map<string, DownloadEntry[]> = new Map()

interface DownloadMenuProps {
  vimeoId: string
  downloadPath?: string
  title: string
}

export function DownloadMenu({
  vimeoId,
  downloadPath,
  title,
}: DownloadMenuProps) {
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
  const listContainerRef = useRef<HTMLDivElement | null>(null)
  const panelId = `download-panel-${vimeoId}`

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

    const cached = downloadsCache.get(vimeoId)
    if (cached) {
      // Sort cached entries by size (desc), then by resolution (desc)
      const sorted = [...cached].sort((a, b) => {
        const sizeA = Number(a.size) || 0
        const sizeB = Number(b.size) || 0
        if (sizeA !== sizeB) return sizeB - sizeA
        const pxA = (Number(a.width) || 0) * (Number(a.height) || 0)
        const pxB = (Number(b.width) || 0) * (Number(b.height) || 0)
        return pxB - pxA
      })
      setEntries(sorted)
      return
    }

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
        // Sort entries by size (desc), then resolution (desc)
        const sorted = [...list].sort((a, b) => {
          const sizeA = Number(a.size) || 0
          const sizeB = Number(b.size) || 0
          if (sizeA !== sizeB) return sizeB - sizeA
          const pxA = (Number(a.width) || 0) * (Number(a.height) || 0)
          const pxB = (Number(b.width) || 0) * (Number(b.height) || 0)
          return pxB - pxA
        })
        downloadsCache.set(vimeoId, sorted)
        setEntries(sorted)
        setError(list.length === 0 ? "No options" : null)
      })
      .catch(() => setError("Unable to load"))
      .finally(() => setLoading(false))
  }, [vimeoId, entries.length, loading, error, isDownloadEntry])

  // Close on outside click
  useEffect(() => {
    if (!open) return
    function onDocMouseDown(e: MouseEvent) {
      const target = e.target as Node
      const root = portalRef.current
      if (root && !root.contains(target)) setOpen(false)
    }
    function onEsc(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false)
    }
    document.addEventListener("mousedown", onDocMouseDown)
    document.addEventListener("keydown", onEsc)
    return () => {
      document.removeEventListener("mousedown", onDocMouseDown)
      document.removeEventListener("keydown", onEsc)
    }
  }, [open])

  // Focus first item when opened
  useEffect(() => {
    if (!open) return
    const container = listContainerRef.current
    if (!container) return
    const firstLink = container.querySelector<HTMLAnchorElement>("a[href]")
    firstLink?.focus()
  }, [open])

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
    const w = Number(download.width) || 0
    const h = Number(download.height) || 0
    // Prefer resolution labels like 1080p when available
    if (h > 0) return `${h}p`
    if (w > 0) return `${w}w`
    if (download.quality) return String(download.quality).toUpperCase()
    if (download.type) return String(download.type).toUpperCase()
    return `Download (${title})`
  }

  function details(download: DownloadEntry): string {
    const parts: string[] = []
    const w = download.width
    const h = download.height
    // Keep explicit dimensions in details for clarity
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
      <Button
        variant="secondary"
        className="border border-transparent shadow-[0_0_0_1px_var(--control-border)]"
        aria-expanded={open}
        aria-controls={panelId}
        aria-label="Download"
        onClick={() => setOpen((v) => !v)}
      >
        <span
          aria-hidden="true"
          className="bg-foreground mr-0 inline-block size-3.5 md:mr-1"
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
        <span className="hidden md:inline">Download</span>
      </Button>
      {open && (
        <div
          id={panelId}
          role="region"
          aria-label="Download options"
          className="border-border bg-background/95 text-foreground absolute -top-2 right-0 z-50 mt-2 w-64 translate-y-[-100%] rounded-md border p-1 shadow-lg"
          ref={listContainerRef}
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
          {!loading && !error && (
            <ul>
              {entries.map((d, idx) => {
                const href = hrefFor(d)
                return (
                  <li key={idx} className="list-none">
                    {href ? (
                      <a
                        href={href}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:bg-foreground/10 focus:bg-foreground/10 focus-visible:ring-ring/50 flex w-full items-center justify-between gap-2 rounded px-2 py-1.5 text-sm transition-colors focus:outline-none focus-visible:ring-2"
                        onClick={() => setOpen(false)}
                      >
                        <span>{qualityLabel(d)}</span>
                        <span className="text-muted-foreground text-xs">
                          {details(d)}
                        </span>
                      </a>
                    ) : (
                      <span className="block px-2 py-1.5 text-sm opacity-70">
                        {qualityLabel(d)}
                      </span>
                    )}
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  )
}
