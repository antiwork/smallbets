import { Head, usePage } from "@inertiajs/react"
import { useEffect, useMemo, useState } from "react"
import type { KeyboardEvent, MouseEvent } from "react"
import { createPortal } from "react-dom"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { MaskedIcon } from "@/components/ui/masked-icon"

interface FeedCardPayload {
  id: number
  title: string
  summary: string | null
  type: "automated" | "promoted"
  createdAt: string
  topMessage: {
    id: number
    bodyHtml: string
    bodyText: string | null
    creatorName: string
    creatorAvatarUrl: string
    opengraph: {
      title: string
      imageUrl: string | null
      href: string
    } | null
  } | null
  room: {
    id: number
    slug: string | null
    name: string
    originalRoomName: string
    icon: string | null
    lastActiveAt: string | null
    messageCount: number
    reactionCount: number
    reactions: string[]
    participants: Array<{
      id: number
      name: string
      avatarUrl: string
    }>
  }
}

type ViewType = "top" | "new"

type CardsByView = Record<ViewType, FeedCardPayload[]>

interface FeedLayoutPayload {
  pageTitle: string
  bodyClass: string
  nav: string
  sidebar: string
}

interface FeedPageProps {
  cardsByView: CardsByView
  initialView: ViewType
  layout: FeedLayoutPayload
  assets?: {
    searchIcon?: string
  }
  flash?: {
    notice?: string
    alert?: string
  }
}

function formatTimeAgo(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)

  if (diffInSeconds < 60) return "just now"
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`
  if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`
  if (diffInSeconds < 2592000)
    return `${Math.floor(diffInSeconds / 604800)}w ago`
  if (diffInSeconds < 31536000)
    return `${Math.floor(diffInSeconds / 2592000)}mo ago`
  return `${Math.floor(diffInSeconds / 31536000)}y ago`
}

function formatActivityStatus(lastActiveAt: string | null): string {
  if (!lastActiveAt) return "Inactive"
  const date = new Date(lastActiveAt)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)

  if (diffInSeconds < 60) return "Active just now"
  if (diffInSeconds < 3600)
    return `Active ${Math.floor(diffInSeconds / 60)}m ago`
  if (diffInSeconds < 86400)
    return `Active ${Math.floor(diffInSeconds / 3600)}h ago`
  if (diffInSeconds < 604800)
    return `Active ${Math.floor(diffInSeconds / 86400)}d ago`
  return `Active ${formatTimeAgo(lastActiveAt)}`
}

function FeedCard({
  card,
  isLast,
}: {
  card: FeedCardPayload
  isLast: boolean
}) {
  const roomUrl = card.room.slug
    ? `/${card.room.slug}`
    : `/rooms/${card.room.id}`

  const isEmoji =
    card.room.icon &&
    /[\p{Emoji_Presentation}\p{Extended_Pictographic}]/u.test(card.room.icon)

  function navigateToRoom(event: MouseEvent<HTMLElement>) {
    if (event.defaultPrevented || event.altKey || event.shiftKey) {
      return
    }

    const interactive = (event.target as HTMLElement | null)?.closest(
      "a, button, [role='button'], [role='link']",
    )
    if (interactive && interactive !== event.currentTarget) {
      return
    }

    if (event.metaKey || event.ctrlKey || event.button === 1) {
      event.preventDefault()
      window.open(roomUrl, "_blank", "noopener,noreferrer")
      return
    }

    if (event.button !== 0) {
      return
    }

    event.preventDefault()
    window.location.href = roomUrl
  }

  function handleCardKeyDown(event: KeyboardEvent<HTMLElement>) {
    if (event.defaultPrevented) return

    const interactive = (event.target as HTMLElement | null)?.closest(
      "a, button, [role='button'], [role='link']",
    )
    if (interactive && interactive !== event.currentTarget) {
      return
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      window.location.href = roomUrl
    }
  }

  return (
    <article
      className="group relative flex cursor-pointer flex-col focus:outline-none"
      role="link"
      tabIndex={0}
      aria-label={`Open ${card.room.originalRoomName}`}
      onClick={navigateToRoom}
      onKeyDown={handleCardKeyDown}
    >
      <div className="bg-background group-hover:bg-accent/50 group-focus-visible:ring-accent relative flex flex-col rounded-lg px-4 py-4 transition-colors group-focus-visible:ring-2 group-focus-visible:ring-offset-2">
        <div className="mb-2 flex items-start gap-1.5">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-full border !border-gray-300 bg-white">
            {isEmoji ? (
              <span className="text-xs">{card.room.icon}</span>
            ) : (
              <span className="text-muted-foreground text-xs font-semibold">
                {card.room.icon || card.room.originalRoomName[0]?.toUpperCase()}
              </span>
            )}
          </div>

          <div className="min-w-0 flex-1">
            <div className="flex items-center">
              <h3 className="text-foreground line-clamp-1 text-xs font-semibold">
                {card.room.originalRoomName}
              </h3>
            </div>
            {card.room.lastActiveAt && (
              <p className="text-muted-foreground text-xs">
                {formatActivityStatus(card.room.lastActiveAt)}
              </p>
            )}
          </div>
        </div>

        <div className="mb-3 flex flex-col gap-1">
          <h2 className="mb-2 text-lg font-semibold">{card.title}</h2>
          {card.summary && (
            <p className="text-muted-foreground line-clamp-2 text-sm">
              {card.summary}
            </p>
          )}
        </div>

        {card.topMessage && (
          <div className="bg-muted/50 mb-3 rounded-md border border-gray-200 p-3">
            {card.topMessage.opengraph ? (
              <div className="flex items-start gap-3">
                <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <div className="flex items-center gap-2">
                    <img
                      src={card.topMessage.creatorAvatarUrl}
                      alt={card.topMessage.creatorName}
                      className="h-5 w-5 rounded-full object-cover"
                    />
                    <span className="text-foreground text-xs font-medium">
                      {card.topMessage.creatorName}
                    </span>
                  </div>
                  <a
                    href={card.topMessage.opengraph.href}
                    target="_blank"
                    rel="noreferrer"
                    className="text-foreground relative z-20 line-clamp-3 text-sm font-medium hover:underline"
                  >
                    {card.topMessage.opengraph.title}
                  </a>
                </div>
                {card.topMessage.opengraph.imageUrl && (
                  <div className="shrink-0">
                    <img
                      src={card.topMessage.opengraph.imageUrl}
                      alt=""
                      className="rounded-lg object-cover"
                      style={{ maxWidth: "120px", maxHeight: "120px" }}
                    />
                  </div>
                )}
              </div>
            ) : (
              <>
                <div className="mb-1 flex items-center gap-2">
                  <img
                    src={card.topMessage.creatorAvatarUrl}
                    alt={card.topMessage.creatorName}
                    className="h-5 w-5 rounded-full object-cover"
                  />
                  <span className="text-foreground text-xs font-medium">
                    {card.topMessage.creatorName}
                  </span>
                </div>

                {card.topMessage.bodyHtml && (
                  <div
                    className="message-preview line-clamp-4"
                    dangerouslySetInnerHTML={{
                      __html: card.topMessage.bodyHtml,
                    }}
                  />
                )}
              </>
            )}
          </div>
        )}

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1">
            {card.room.participants.length > 0 && (
              <div className="flex -space-x-2">
                {card.room.participants.slice(0, 4).map((participant) => (
                  <img
                    key={participant.id}
                    src={participant.avatarUrl}
                    alt={participant.name}
                    className="border-background h-7 w-7 rounded-full border-2 object-cover"
                    title={participant.name}
                  />
                ))}
              </div>
            )}

            <span className="text-muted-foreground text-sm">
              {card.room.messageCount}{" "}
              {card.room.messageCount === 1 ? "message" : "messages"}
            </span>
          </div>

          {card.room.reactions.length > 0 ? (
            <div className="flex items-center">
              <div className="flex -space-x-1.5">
                {card.room.reactions.slice(0, 5).map((emoji, index) => (
                  <span
                    key={index}
                    className="border-background bg-muted flex size-6 items-center justify-center rounded-full border-2 text-xs leading-none"
                    title={`Reaction: ${emoji}`}
                  >
                    {emoji}
                  </span>
                ))}
              </div>
              {card.room.reactions.length > 5 && (
                <span className="text-muted-foreground ml-1 text-xs">+</span>
              )}
            </div>
          ) : null}
        </div>
      </div>
      {!isLast && (
        <>
          <div className="h-1" />
          <div className="border-input h-px border-t" />
          <div className="h-1" />
        </>
      )}
    </article>
  )
}

export default function FeedIndex({
  cardsByView,
  initialView,
  layout,
  assets,
  flash,
}: FeedPageProps) {
  const { url } = usePage()

  const derivedInitialView: ViewType = initialView ?? "top"
  const [view, setView] = useState<ViewType>(derivedInitialView)
  const [cardsState, setCardsState] = useState<CardsByView>(() => ({
    top: cardsByView.top ?? [],
    new: cardsByView.new ?? [],
  }))
  const [searchRoot, setSearchRoot] = useState<HTMLElement | null>(null)

  useEffect(() => {
    if (!layout) return

    if (layout.bodyClass) {
      document.body.className = layout.bodyClass
    }

    if (layout.nav) {
      const nav = document.getElementById("nav")
      if (nav) {
        nav.innerHTML = layout.nav
        const node = document.getElementById("feed-search-root")
        setSearchRoot(node)
      }
    }

    if (layout.sidebar) {
      const sidebar = document.getElementById("sidebar")
      if (sidebar) sidebar.innerHTML = layout.sidebar
    }
  }, [layout?.bodyClass, layout?.nav, layout?.sidebar])

  useEffect(() => {
    if (flash?.notice) {
      toast.success(flash.notice)
    }
    if (flash?.alert) {
      toast.error(flash.alert)
    }
  }, [flash])

  useEffect(() => {
    const urlParams = new URLSearchParams(url.split("?")[1] || "")
    const viewParam = urlParams.get("view")
    const nextView: ViewType = viewParam === "new" ? "new" : "top"
    setView(nextView)
  }, [url])

  useEffect(() => {
    setCardsState({
      top: cardsByView.top ?? [],
      new: cardsByView.new ?? [],
    })
  }, [cardsByView.top, cardsByView.new])

  const sortedCards = useMemo(() => {
    const selectedCards = cardsState[view] ?? []

    if (view === "new") {
      return [...selectedCards].sort((a, b) => {
        const aTime = new Date(a.createdAt).getTime()
        const bTime = new Date(b.createdAt).getTime()
        return bTime - aTime
      })
    }

    return selectedCards
  }, [cardsState, view])

  function handleViewChange(newView: ViewType) {
    if (newView === view) return

    const targetUrl = new URL(window.location.href)
    targetUrl.searchParams.set("view", newView)

    setView(newView)
    window.history.replaceState({}, "", targetUrl.toString())
  }

  const searchButton = (
    <div className="relative mr-3 ml-auto hidden items-center lg:flex">
      <Button
        type="button"
        variant="ghost"
        size="icon-lg"
        className="border-input bg-background size-10 rounded-full border shadow-[0_0_0_1px_var(--control-border)]"
        aria-label="Open search"
        onClick={() => {
          window.location.href = "/searches"
        }}
      >
        <MaskedIcon src={assets?.searchIcon} />
      </Button>
    </div>
  )

  return (
    <div className="bg-background min-h-screen py-12">
      <Head title={layout?.pageTitle || "Home"} />
      <h1 className="sr-only">Home</h1>

      {searchRoot ? createPortal(searchButton, searchRoot) : null}

      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        <div className="mt-6 mb-3 ml-1 flex items-center">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                className="bg-background flex items-center justify-between gap-2 rounded-lg"
              >
                <span className="pointer-events-none text-sm">
                  {view === "top" ? "Top" : "New"}
                </span>
                <svg
                  className="pointer-events-none size-4 opacity-50"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19 9l-7 7-7-7"
                  />
                </svg>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start">
              <DropdownMenuItem
                onClick={() => handleViewChange("top")}
                className={view === "top" ? "bg-accent" : ""}
              >
                Top
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => handleViewChange("new")}
                className={view === "new" ? "bg-accent" : ""}
              >
                New
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {sortedCards.length === 0 ? (
          <div className="bg-background border-input rounded-lg border p-12 text-center">
            <p className="text-muted-foreground">
              No feed cards yet. Check back soon!
            </p>
          </div>
        ) : (
          <div className="flex flex-col">
            {sortedCards.map((card, index) => (
              <FeedCard
                key={card.id}
                card={card}
                isLast={index === sortedCards.length - 1}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
