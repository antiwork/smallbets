import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import {
  getAutoplaySoundEnabled,
  setAutoplaySoundEnabled,
  subscribeToAutoplaySound,
} from "../autoplay_audio_pref"
import type { LibrarySessionPayload, LibraryWatchPayload } from "../../../types"
import type { WatchPayload } from "../watch_history"
import { FullscreenInfoBar } from "./fullscreen-info-bar"
import { persistProgress } from "./progress"
import { createProgressThrottler } from "./progress-throttler"
import {
  postToVimeo,
  isVimeoEvent,
  normalizeData,
  subscribeToEvents,
} from "./vimeo-messaging"
import { PROGRESS_THROTTLE_MS, MUTE_OVERLAY_HOLD_MS } from "./constants"
import type { PlaybackStatus } from "./types"

const RESUME_TAIL_RESET_SECONDS = 10

function computeResumeTime(watch: WatchPayload | null | undefined): number {
  if (!watch) return 0
  const played = watch.playedSeconds ?? 0
  const duration = watch.durationSeconds ?? null
  if (watch.completed) return 0
  if (typeof duration === "number" && duration > 0) {
    const remaining = duration - played
    if (remaining <= RESUME_TAIL_RESET_SECONDS) return 0
  }
  return played
}

export interface VimeoEmbedProps {
  session: LibrarySessionPayload
  shouldPlay: boolean
  playerSrc: string
  isFullscreen: boolean
  resetPreviewSignal: number
  watchOverride?: LibraryWatchPayload | null
  onWatchUpdate?: (watch: LibraryWatchPayload) => void
  backIcon?: string
  onExitFullscreen?: () => void
  persistPreview?: boolean
  onFrameLoad?: () => void
  onReady?: () => void
}

export function VimeoEmbed({
  session,
  shouldPlay,
  playerSrc,
  isFullscreen,
  resetPreviewSignal,
  watchOverride,
  onWatchUpdate,
  backIcon,
  onExitFullscreen,
  persistPreview,
  onFrameLoad,
  onReady,
}: VimeoEmbedProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null)
  const overlayRef = useRef<HTMLDivElement | null>(null)
  const backButtonRef = useRef<HTMLButtonElement | null>(null)
  const previousFocusRef = useRef<HTMLElement | null>(null)
  const [isReady, setIsReady] = useState(false)
  const [, setStatus] = useState<PlaybackStatus>({ state: "idle" })
  const [autoplaySoundEnabled, setAutoplaySoundState] = useState(
    getAutoplaySoundEnabled(),
  )
  const progressRef = useRef<WatchPayload | null>(
    watchOverride ?? session.watch ?? null,
  )
  const fallbackOriginRef = useRef<string>(new URL(playerSrc).origin)
  const vimeoOriginRef = useRef<string | null>(null)
  const fullscreenStateRef = useRef(isFullscreen)
  const previousFullscreenRef = useRef(isFullscreen)
  const pendingPreviewResetRef = useRef(false)
  const lastPreviewResetSignalRef = useRef(resetPreviewSignal)
  const hasPersistedHistoryRef = useRef((session.watch?.playedSeconds ?? 0) > 0)
  const [isButtonHovered, setIsButtonHovered] = useState(false)
  const [isBgVisible, setIsBgVisible] = useState(false)
  const bgHoldTimerRef = useRef<number | null>(null)

  const watchPath = session.watchHistoryPath
  const dialogTitleId = useMemo(
    () => `player-title-${session.id}`,
    [session.id],
  )

  const markHistoryPersisted = useCallback(() => {
    hasPersistedHistoryRef.current = true
  }, [])

  const throttler = useMemo(
    () =>
      createProgressThrottler(PROGRESS_THROTTLE_MS, (payload, options) => {
        void persistProgress(watchPath, payload, setStatus, options).then(
          (success) => {
            if (success) {
              markHistoryPersisted()
              if (onWatchUpdate) onWatchUpdate(payload)
            }
          },
        )
      }),
    [markHistoryPersisted, watchPath, onWatchUpdate],
  )

  useEffect(() => {
    progressRef.current = watchOverride ?? session.watch ?? null
  }, [watchOverride, session.watch])

  useEffect(() => {
    hasPersistedHistoryRef.current = (session.watch?.playedSeconds ?? 0) > 0
  }, [session.watch])

  useEffect(() => {
    fallbackOriginRef.current = new URL(playerSrc).origin
    vimeoOriginRef.current = null
    setIsReady(false)
  }, [playerSrc])

  // Reset readiness when toggling fullscreen so skeleton shows until ready
  useEffect(() => {
    setIsReady(false)
  }, [isFullscreen])

  useEffect(() => {
    fullscreenStateRef.current = isFullscreen
  }, [isFullscreen])

  // Focus management for fullscreen dialog
  useEffect(() => {
    if (!isFullscreen) return
    previousFocusRef.current = (document.activeElement as HTMLElement) || null
    // Focus the back button when entering
    const timeout = window.setTimeout(() => {
      backButtonRef.current?.focus()
    }, 0)

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key !== "Tab") return
      const container = overlayRef.current
      if (!container) return
      const focusable = Array.from(
        container.querySelectorAll<HTMLElement>(
          'a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((el) => !el.hasAttribute("disabled") && el.tabIndex !== -1)
      if (focusable.length === 0) return
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      const active = document.activeElement as HTMLElement | null
      if (e.shiftKey) {
        if (active === first || !container.contains(active)) {
          e.preventDefault()
          last.focus()
        }
      } else {
        if (active === last || !container.contains(active)) {
          e.preventDefault()
          first.focus()
        }
      }
    }

    document.addEventListener("keydown", handleKeyDown)
    return () => {
      window.clearTimeout(timeout)
      document.removeEventListener("keydown", handleKeyDown)
      // Restore focus on exit
      previousFocusRef.current?.focus?.()
    }
  }, [isFullscreen])

  const resetPreviewPlayback = useCallback(() => {
    const frame = frameRef.current
    if (!frame) return
    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "pause" },
      { fallbackOrigin: fallbackOriginRef.current },
    )
    const resumeAt = computeResumeTime(progressRef.current)
    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "setCurrentTime", value: resumeAt },
      { fallbackOrigin: fallbackOriginRef.current },
    )
    pendingPreviewResetRef.current = false
  }, [])

  useEffect(() => {
    if (
      resetPreviewSignal === lastPreviewResetSignalRef.current &&
      !pendingPreviewResetRef.current
    )
      return
    if (fullscreenStateRef.current) return
    if (resetPreviewSignal !== lastPreviewResetSignalRef.current) {
      lastPreviewResetSignalRef.current = resetPreviewSignal
      pendingPreviewResetRef.current = true
    }
    if (isReady && pendingPreviewResetRef.current) resetPreviewPlayback()
  }, [resetPreviewSignal, isReady, resetPreviewPlayback])

  const handleVimeoMessage = useCallback(
    (message: any) => {
      switch (message.event) {
        case "ready": {
          subscribeToEvents(
            frameRef.current,
            vimeoOriginRef,
            fallbackOriginRef.current,
          )
          setIsReady(true)
          if (onReady) onReady()
          try {
            performance.mark(`vimeo:ready:${session.id}`)
            performance.measure(
              `vimeo:activation→ready:${session.id}`,
              `vimeo:activate:${session.id}`,
              `vimeo:ready:${session.id}`,
            )
          } catch (_e) {
            // ignore
          }
          break
        }
        case "timeupdate": {
          const next: WatchPayload = {
            playedSeconds: message.data.seconds,
            durationSeconds: message.data.duration,
            completed: false,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (onWatchUpdate) onWatchUpdate(next)
          if (fullscreenStateRef.current || persistPreview)
            throttler.queue(next)
          break
        }
        case "seeked": {
          const next: WatchPayload = {
            playedSeconds: message.data.seconds,
            durationSeconds: message.data.duration,
            completed: false,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (onWatchUpdate) onWatchUpdate(next)
          if (fullscreenStateRef.current || persistPreview)
            throttler.flush(next)
          break
        }
        case "pause": {
          const metrics = message.data
          if (metrics) {
            const next: WatchPayload = {
              playedSeconds: metrics.seconds,
              durationSeconds: metrics.duration,
              completed: false,
              lastWatchedAt: new Date().toISOString(),
            }
            progressRef.current = next
            if (onWatchUpdate) onWatchUpdate(next)
          }
          if (fullscreenStateRef.current || persistPreview)
            throttler.flush(progressRef.current ?? undefined)
          break
        }
        case "ended": {
          const duration =
            progressRef.current?.durationSeconds ??
            progressRef.current?.playedSeconds ??
            0
          const next: WatchPayload = {
            playedSeconds: duration,
            durationSeconds: duration,
            completed: true,
            lastWatchedAt: new Date().toISOString(),
          }
          progressRef.current = next
          if (onWatchUpdate) onWatchUpdate(next)
          if (fullscreenStateRef.current || persistPreview)
            throttler.flush(next)
          break
        }
        default:
          break
      }
    },
    [throttler, persistPreview],
  )

  useEffect(() => {
    const frame = frameRef.current
    if (!frame) return
    const handleMessage = (event: MessageEvent) => {
      if (
        !isVimeoEvent(event, frame, vimeoOriginRef, fallbackOriginRef.current)
      )
        return
      const payload = normalizeData(event.data)
      if (!payload) return
      handleVimeoMessage(payload)
    }
    window.addEventListener("message", handleMessage)
    postToVimeo(
      frame,
      vimeoOriginRef,
      { method: "ping" },
      { allowWildcard: true, fallbackOrigin: fallbackOriginRef.current },
    )
    return () => window.removeEventListener("message", handleMessage)
  }, [handleVimeoMessage, playerSrc, isFullscreen])

  useEffect(() => {
    if (previousFullscreenRef.current && !isFullscreen) {
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
    }
    previousFullscreenRef.current = isFullscreen
  }, [isFullscreen, throttler])

  useEffect(() => {
    function flushWithKeepalive(): void {
      if (!fullscreenStateRef.current && !persistPreview) return
      throttler.flush(progressRef.current ?? undefined, { keepalive: true })
    }
    const handleVisibilityChange = () => {
      if (document.visibilityState !== "hidden") return
      flushWithKeepalive()
    }
    const handlePageHide = () => flushWithKeepalive()
    const handleBeforeUnload = () => flushWithKeepalive()
    document.addEventListener("visibilitychange", handleVisibilityChange)
    window.addEventListener("pagehide", handlePageHide)
    window.addEventListener("beforeunload", handleBeforeUnload)
    return () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange)
      window.removeEventListener("pagehide", handlePageHide)
      window.removeEventListener("beforeunload", handleBeforeUnload)
    }
  }, [throttler, persistPreview])

  useEffect(() => {
    return () => {
      if (fullscreenStateRef.current || persistPreview) {
        throttler.flush(progressRef.current ?? undefined, { keepalive: true })
      }
      throttler.cancel()
    }
  }, [throttler, persistPreview])

  useEffect(() => {
    const resumeAt = computeResumeTime(progressRef.current)
    if (!isReady || resumeAt == null || !frameRef.current) return
    postToVimeo(frameRef.current, vimeoOriginRef, {
      method: "setCurrentTime",
      value: resumeAt,
    })
  }, [isReady])

  useEffect(() => {
    const unsubscribe = subscribeToAutoplaySound((enabled) =>
      setAutoplaySoundState(enabled),
    )
    return () => {
      unsubscribe()
    }
  }, [])

  useEffect(() => {
    if (isFullscreen) {
      setIsBgVisible(false)
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
      return
    }
    if (!shouldPlay) {
      setIsBgVisible(false)
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
      return
    }
    setIsBgVisible(true)
    if (!isButtonHovered) {
      if (bgHoldTimerRef.current) window.clearTimeout(bgHoldTimerRef.current)
      bgHoldTimerRef.current = window.setTimeout(() => {
        setIsBgVisible(false)
        bgHoldTimerRef.current = null
      }, MUTE_OVERLAY_HOLD_MS)
    }
    return () => {
      if (bgHoldTimerRef.current) {
        window.clearTimeout(bgHoldTimerRef.current)
        bgHoldTimerRef.current = null
      }
    }
  }, [shouldPlay, isFullscreen, isButtonHovered])

  const handleButtonEnter = useCallback(() => {
    setIsButtonHovered(true)
    setIsBgVisible(true)
    if (bgHoldTimerRef.current) {
      window.clearTimeout(bgHoldTimerRef.current)
      bgHoldTimerRef.current = null
    }
  }, [])

  const handleButtonLeave = useCallback(() => {
    setIsButtonHovered(false)
    if (!shouldPlay || isFullscreen) return
    if (bgHoldTimerRef.current) window.clearTimeout(bgHoldTimerRef.current)
    bgHoldTimerRef.current = window.setTimeout(() => {
      setIsBgVisible(false)
      bgHoldTimerRef.current = null
    }, MUTE_OVERLAY_HOLD_MS)
  }, [shouldPlay, isFullscreen])

  const syncVolume = useCallback(
    (frame: HTMLIFrameElement | null) => {
      if (!isReady || !frame) return
      const enableSound = isFullscreen || autoplaySoundEnabled
      postToVimeo(
        frame,
        vimeoOriginRef,
        { method: "setVolume", value: enableSound ? 1 : 0 },
        { fallbackOrigin: fallbackOriginRef.current },
      )
    },
    [autoplaySoundEnabled, isFullscreen, isReady],
  )

  useEffect(() => {
    syncVolume(frameRef.current)
  }, [syncVolume])

  useEffect(() => {
    const frame = frameRef.current
    if (!isReady || !frame) return
    if (shouldPlay) syncVolume(frame)
    postToVimeo(frame, vimeoOriginRef, {
      method: shouldPlay ? "play" : "pause",
    })
  }, [isReady, shouldPlay, syncVolume])

  useEffect(() => {
    syncVolume(frameRef.current)
  }, [isFullscreen, syncVolume])

  const toggleAutoplaySound = useCallback(() => {
    setAutoplaySoundEnabled(!autoplaySoundEnabled)
  }, [autoplaySoundEnabled])

  return (
    <div className="bg-background relative size-full">
      {!isReady &&
        (isFullscreen ? (
          <div
            aria-hidden
            className="fixed inset-0 z-[1001] flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 opacity-80 motion-safe:animate-[pulse_8s_ease-in-out_infinite]"
          />
        ) : (
          <div
            aria-hidden
            className="absolute inset-0 z-[1] flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 opacity-80 motion-safe:animate-[pulse_8s_ease-in-out_infinite]"
          />
        ))}
      {!isFullscreen ? (
        <div className="absolute inset-0">
          <iframe
            ref={frameRef}
            title={session.title}
            src={playerSrc}
            className="vimeo-embed size-full"
            allow="autoplay; picture-in-picture; clipboard-write"
            loading="lazy"
            referrerPolicy="strict-origin-when-cross-origin"
            onLoad={onFrameLoad}
          />
        </div>
      ) : (
        <div
          ref={overlayRef}
          role="dialog"
          aria-modal="true"
          aria-labelledby={dialogTitleId}
          className="bg-background fixed inset-0 z-[999] flex flex-col"
          style={{ "--bar-h": "72px" }}
        >
          <button
            ref={backButtonRef}
            type="button"
            onClick={onExitFullscreen}
            aria-label="Go Back"
            className="bg-background/60! text-foreground hover:bg-background/80! absolute top-4 left-4 z-[1000] flex size-10 items-center justify-center rounded-full border border-transparent shadow-[0_0_0_1px_var(--control-border)] transition-opacity"
          >
            {backIcon && (
              <span
                aria-hidden="true"
                className="bg-foreground inline-block size-5"
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
            )}
          </button>
          <div className="flex flex-1 items-center justify-center">
            <iframe
              ref={frameRef}
              title={session.title}
              src={playerSrc}
              className="vimeo-embed h-auto max-h-[calc(100vh-var(--bar-h))] w-[100vw]"
              style={{ aspectRatio: "16 / 9" }}
              allow="fullscreen; autoplay; picture-in-picture; clipboard-write"
              loading="eager"
              allowFullScreen={true}
              referrerPolicy="strict-origin-when-cross-origin"
              onLoad={onFrameLoad}
            />
          </div>
          <nav
            role="toolbar"
            aria-label="Player controls"
            className="bg-background text-foreground"
          >
            <FullscreenInfoBar
              title={session.title}
              creator={session.creator}
              vimeoId={session.vimeoId}
              downloadPath={session.downloadPath}
            />
          </nav>
        </div>
      )}

      {!isFullscreen && shouldPlay && (
        <button
          type="button"
          aria-pressed={autoplaySoundEnabled}
          aria-label={autoplaySoundEnabled ? "Mute" : "Unmute"}
          onMouseDown={(e) => e.stopPropagation()}
          onTouchStart={(e) => e.stopPropagation()}
          onClick={(e) => {
            e.stopPropagation()
            toggleAutoplaySound()
          }}
          onMouseEnter={handleButtonEnter}
          onMouseLeave={handleButtonLeave}
          className={[
            "text-foreground pointer-events-auto absolute top-2.5 right-2.5 z-[2] flex size-9 items-center justify-center overflow-hidden rounded-full hover:!shadow-none",
            "before:bg-background before:pointer-events-none before:absolute before:inset-0 before:rounded-full before:transition-opacity before:ease-out before:content-['']",
            isBgVisible || isButtonHovered
              ? "before:opacity-60 before:duration-150"
              : "before:opacity-0 before:duration-500",
          ].join(" ")}
        >
          {autoplaySoundEnabled ? (
            <svg
              viewBox="0 0 40 40"
              className="relative z-10 size-8 drop-shadow-[0_1px_1px_rgba(0,0,0,0.6)]"
            >
              <path
                d="M6 17.6469V22.6307C6 24.4433 7.46986 25.9174 9.28676 25.9174H12.5001V14.3616H9.28676C7.47412 14.3616 6 15.8315 6 17.6484V17.6469Z"
                fill="white"
              />
              <path
                d="M20.466 9.70226L13.9446 14.36V25.9158L20.466 30.5735C21.9684 31.6456 24.0561 30.5735 24.0561 28.7284V11.5471C24.0561 9.70197 21.9684 8.63021 20.466 9.70226Z"
                fill="white"
              />
              <path
                d="M27.5105 14.9944C27.136 14.6199 26.5294 14.6199 26.1561 14.9944C25.7816 15.3689 25.7816 15.9756 26.1561 16.3488C27.3033 17.496 27.9324 19.0202 27.9324 20.6406C27.9324 22.2608 27.2995 23.7888 26.1561 24.9323C25.7816 25.3068 25.7816 25.9135 26.1561 26.2867C26.3446 26.4752 26.588 26.5676 26.8339 26.5676C27.0798 26.5676 27.3258 26.4752 27.5118 26.2867C29.0197 24.7787 29.8511 22.7715 29.8511 20.6368C29.8511 18.5022 29.0197 16.495 27.5118 14.987L27.5105 14.9944Z"
                fill="white"
              />
              <path
                d="M28.8663 12.2845C28.4918 12.659 28.4918 13.2657 28.8663 13.6389C32.7298 17.5024 32.7298 23.785 28.8663 27.6486C28.4918 28.0231 28.4918 28.6297 28.8663 29.003C29.0548 29.1915 29.2982 29.2838 29.5441 29.2838C29.7901 29.2838 30.036 29.1915 30.222 29.003C34.8333 24.3917 34.8333 16.8922 30.222 12.2809C29.8475 11.9064 29.2408 11.9064 28.8676 12.2809L28.8663 12.2845Z"
                fill="white"
              />
            </svg>
          ) : (
            <svg
              viewBox="0 0 40 40"
              className="relative z-10 size-8 drop-shadow-[0_1px_1px_rgba(0,0,0,0.6)]"
            >
              <path
                d="M6 17.6469V22.6307C6 24.4433 7.46986 25.9174 9.28676 25.9174H12.5001V14.3616H9.28676C7.47412 14.3616 6 15.8315 6 17.6484V17.6469Z"
                fill="white"
              />
              <path
                d="M20.466 9.70226L13.9446 14.36V25.9158L20.466 30.5735C21.9684 31.6456 24.0561 30.5735 24.0561 28.7284V11.5471C24.0561 9.70197 21.9684 8.63021 20.466 9.70226Z"
                fill="white"
              />
              <path
                d="M31.9059 20.1378L34.2094 17.8343C34.6326 17.4111 34.6326 16.7255 34.2094 16.3037C33.7862 15.8805 33.1007 15.8805 32.6789 16.3037L30.3753 18.6073L28.0718 16.3037C27.6486 15.8805 26.9631 15.8805 26.5413 16.3037C26.1181 16.7269 26.1181 17.4125 26.5413 17.8343L28.8448 20.1378L26.5413 22.4413C26.1181 22.8645 26.1181 23.5501 26.5413 23.9719C26.7543 24.1849 27.0294 24.2893 27.3072 24.2893C27.5851 24.2893 27.863 24.1849 28.0732 23.9719L30.3768 21.6683L32.6803 23.9719C32.8933 24.1849 33.1684 24.2893 33.4463 24.2893C33.7242 24.2893 34.0021 24.1849 34.2122 23.9719C34.6354 23.5487 34.6354 22.8631 34.2122 22.4413L31.9087 20.1378H31.9059Z"
                fill="white"
              />
            </svg>
          )}
        </button>
      )}
    </div>
  )
}
