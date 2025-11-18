import { Head, usePage } from "@inertiajs/react"
import type { PageProps as InertiaPageProps } from "@inertiajs/core"
import { useEffect, useMemo } from "react"

import { FullscreenVimeoPlayer } from "@/pages/library/components/player"
import type { LibraryWatchPayload } from "./types"
import type { LibrarySessionPayload, LibraryLayoutPayload } from "./types"

type LayoutPayload = LibraryLayoutPayload

interface AppPageProps extends InertiaPageProps {
  session: LibrarySessionPayload
  assets?: { backIcon?: string; downloadIcon?: string }
  layout?: LayoutPayload
}

export default function LibraryWatch() {
  const { props } = usePage<AppPageProps>()
  const { session, assets, layout } = props
  const watchOverride = useMemo<LibraryWatchPayload | null>(() => {
    if (typeof window === "undefined") return null
    try {
      const key = `library:preview:${session.id}`
      const raw = sessionStorage.getItem(key)
      if (!raw) return null
      const parsed = JSON.parse(raw) as LibraryWatchPayload
      sessionStorage.removeItem(key)
      return parsed
    } catch (_e) {
      return null
    }
  }, [session.id])

  useEffect(() => {
    if (!layout) return
    if (layout.bodyClass) document.body.className = layout.bodyClass
    if (layout.nav) {
      const nav = document.getElementById("nav")
      if (nav) nav.innerHTML = layout.nav
    }
    if (layout.sidebar) {
      const sidebar = document.getElementById("sidebar")
      if (sidebar) sidebar.innerHTML = layout.sidebar
    }
  }, [layout?.bodyClass, layout?.nav, layout?.sidebar])

  return (
    <div className="bg-background min-h-screen">
      <Head title={session.title} />
      <h1 className="sr-only">{session.title}</h1>
      <section aria-label="Video player" className="relative min-h-screen">
        <FullscreenVimeoPlayer
          session={{
            ...session,
            watch: watchOverride ?? session.watch ?? null,
          }}
          backIcon={assets?.backIcon}
        />
      </section>
    </div>
  )
}
