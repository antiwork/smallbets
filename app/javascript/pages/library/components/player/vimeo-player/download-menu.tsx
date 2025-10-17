import { useCallback, useEffect, useRef, useState } from "react"
import { usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
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
      setEntries(cached)
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
        downloadsCache.set(vimeoId, list)
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
    return `Download (${title})`
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
