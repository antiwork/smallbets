import { useCallback, useEffect, useMemo } from "react"
import { router } from "@inertiajs/react"
import type { LibrarySessionPayload } from "../../../types"
import { VimeoEmbed } from "./vimeo-embed"

interface FullscreenPageProps {
  session: LibrarySessionPayload
  backIcon?: string
}

export function FullscreenVimeoPlayer({
  session,
  backIcon,
}: FullscreenPageProps) {
  const handleExit = useCallback(() => {
    router.visit("/library", { replace: true, preserveScroll: true })
  }, [])

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") handleExit()
    }
    document.addEventListener("keydown", onKeyDown)
    document.body.style.overflow = "hidden"
    return () => {
      document.removeEventListener("keydown", onKeyDown)
      document.body.style.overflow = ""
    }
  }, [handleExit])
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

  return (
    <VimeoEmbed
      session={session}
      shouldPlay={true}
      playerSrc={playerSrc}
      isFullscreen={true}
      resetPreviewSignal={0}
      watchOverride={session.watch}
      onWatchUpdate={undefined}
      backIcon={backIcon}
      onExitFullscreen={handleExit}
      persistPreview={false}
    />
  )
}
