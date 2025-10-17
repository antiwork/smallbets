import { Head, usePage } from "@inertiajs/react"
import type { PageProps as InertiaPageProps } from "@inertiajs/core"
import { useEffect } from "react"

import FullscreenVimeoPlayer from "./components/player/fullscreen_vimeo_player"

interface LibrarySessionPayload {
  id: number
  title: string
  description: string
  categories: LibraryCategoryPayload[]
  padding: number
  vimeoId: string
  vimeoHash?: string
  creator: string
  playerSrc: string
  downloadPath: string
  position: number
  watchHistoryPath: string
  watch?: LibraryWatchPayload | null
}

interface LibraryCategoryPayload {
  id: number
  name: string
  slug: string
}

interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

interface LayoutPayload {
  pageTitle?: string
  bodyClass?: string
  nav?: string
  sidebar?: string
}

interface AppPageProps extends InertiaPageProps {
  session: LibrarySessionPayload
  assets?: { backIcon?: string; downloadIcon?: string }
  layout?: LayoutPayload
}

export default function LibraryWatch() {
  const { props } = usePage<AppPageProps>()
  const { session, assets, layout } = props

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
    <div className="min-h-screen bg-black">
      <Head title={session.title} />
      <div className="relative min-h-screen">
        <FullscreenVimeoPlayer session={session} backIcon={assets?.backIcon} />
      </div>
    </div>
  )
}
