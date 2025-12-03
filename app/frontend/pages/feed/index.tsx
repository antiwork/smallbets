import { Head, usePage } from "@inertiajs/react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import type { KeyboardEvent, MouseEvent } from "react"
import { createPortal } from "react-dom"
import { toast } from "sonner"
import { MoreHorizontal, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { MaskedIcon } from "@/components/ui/masked-icon"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"

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

interface PaginationConfig {
  initialLimit: number
  loadMoreLimit: number
}

interface ViewerPayload {
  isAdministrator: boolean
}

interface FeedPageProps {
  cardsByView: CardsByView
  initialView: ViewType
  pagination: PaginationConfig
  viewer?: ViewerPayload
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
  isAdministrator,
  onDelete,
}: {
  card: FeedCardPayload
  isLast: boolean
  isAdministrator: boolean
  onDelete?: (cardId: number) => void
}) {
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false)

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
      "a, button, [role='button'], [role='link'], [data-radix-collection-item]",
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
      "a, button, [role='button'], [role='link'], [data-radix-collection-item]",
    )
    if (interactive && interactive !== event.currentTarget) {
      return
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      window.location.href = roomUrl
    }
  }

  function handleDeleteClick() {
    setIsDeleteDialogOpen(true)
  }

  function handleConfirmDelete() {
    setIsDeleteDialogOpen(false)
    onDelete?.(card.id)
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

          {isAdministrator && (
            <>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    className="text-muted-foreground hover:text-foreground -mr-2 opacity-0 transition-opacity group-hover:opacity-100 data-[state=open]:opacity-100"
                    aria-label="Card options"
                  >
                    <MoreHorizontal className="size-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem
                    className="text-destructive focus:text-destructive"
                    onSelect={handleDeleteClick}
                  >
                    <Trash2 className="mr-2 size-4" />
                    Delete card
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>

              <AlertDialog
                open={isDeleteDialogOpen}
                onOpenChange={setIsDeleteDialogOpen}
              >
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Delete this card?</AlertDialogTitle>
                    <AlertDialogDescription>
                      This will permanently delete the feed card and its
                      associated conversation room. This action cannot be
                      undone.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      variant="destructive"
                      onClick={handleConfirmDelete}
                    >
                      Delete
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </>
          )}
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
                    className="text-foreground line-clamp-3 text-sm font-medium hover:underline"
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
  pagination,
  viewer,
  layout,
  assets,
  flash,
}: FeedPageProps) {
  const { url } = usePage()

  const isAdministrator = viewer?.isAdministrator ?? false
  const derivedInitialView: ViewType = initialView ?? "top"
  const [view, setView] = useState<ViewType>(derivedInitialView)
  const [cardsState, setCardsState] = useState<CardsByView>(() => ({
    top: cardsByView.top ?? [],
    new: cardsByView.new ?? [],
  }))
  const [searchRoot, setSearchRoot] = useState<HTMLElement | null>(null)
  const [pageByView, setPageByView] = useState<Record<ViewType, number>>({
    top: 1,
    new: 1,
  })
  const [hasMoreByView, setHasMoreByView] = useState<Record<ViewType, boolean>>(
    {
      top: (cardsByView.top?.length ?? 0) >= (pagination?.initialLimit ?? 20),
      new: (cardsByView.new?.length ?? 0) >= (pagination?.initialLimit ?? 20),
    },
  )
  const [isLoading, setIsLoading] = useState(false)
  const loadMoreRef = useRef<HTMLDivElement>(null)
  const previousCardsRef = useRef<CardsByView | null>(null)

  const loadMoreCards = useCallback(async () => {
    if (isLoading || !hasMoreByView[view]) return

    setIsLoading(true)
    const nextPage = pageByView[view] + 1

    try {
      const response = await fetch(`/?view=${view}&page=${nextPage}`, {
        headers: {
          Accept: "application/json",
        },
      })

      if (!response.ok) throw new Error("Failed to fetch")

      const data = await response.json()
      const newCards: FeedCardPayload[] = data.feedCards ?? []

      if (newCards.length > 0) {
        setCardsState((prev) => ({
          ...prev,
          [view]: [...prev[view], ...newCards],
        }))
        setPageByView((prev) => ({ ...prev, [view]: nextPage }))
      }

      setHasMoreByView((prev) => ({
        ...prev,
        [view]: data.hasMore ?? false,
      }))
    } catch (error) {
      console.error("Error loading more cards:", error)
      toast.error("Failed to load more cards")
    } finally {
      setIsLoading(false)
    }
  }, [view, pageByView, hasMoreByView, isLoading])

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const [entry] = entries
        if (entry?.isIntersecting && hasMoreByView[view] && !isLoading) {
          loadMoreCards()
        }
      },
      {
        rootMargin: "800px",
        threshold: 0,
      },
    )

    const currentRef = loadMoreRef.current
    if (currentRef) {
      observer.observe(currentRef)
    }

    return () => {
      if (currentRef) {
        observer.unobserve(currentRef)
      }
    }
  }, [loadMoreCards, hasMoreByView, view, isLoading])

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
    setPageByView({ top: 1, new: 1 })
    setHasMoreByView({
      top: (cardsByView.top?.length ?? 0) >= (pagination?.initialLimit ?? 20),
      new: (cardsByView.new?.length ?? 0) >= (pagination?.initialLimit ?? 20),
    })
  }, [cardsByView.top, cardsByView.new, pagination?.initialLimit])

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

  async function handleDeleteCard(cardId: number) {
    // Store current state for rollback
    previousCardsRef.current = { ...cardsState }

    // Optimistic update: remove card from both views
    setCardsState((prev) => ({
      top: prev.top.filter((c) => c.id !== cardId),
      new: prev.new.filter((c) => c.id !== cardId),
    }))

    try {
      const csrfToken = document
        .querySelector('meta[name="csrf-token"]')
        ?.getAttribute("content")

      const response = await fetch(`/feed/${cardId}`, {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
        },
      })

      if (!response.ok) {
        throw new Error(
          response.status === 403
            ? "You don't have permission to delete this card"
            : "Failed to delete card",
        )
      }

      toast.success("Card deleted successfully")
      previousCardsRef.current = null
    } catch (error) {
      // Rollback on failure
      if (previousCardsRef.current) {
        setCardsState(previousCardsRef.current)
        previousCardsRef.current = null
      }
      toast.error(
        error instanceof Error ? error.message : "Failed to delete card",
      )
    }
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
          <Tabs
            value={view}
            onValueChange={(value) => handleViewChange(value as ViewType)}
            className="w-auto"
          >
            <TabsList className="bg-background h-9 gap-0 rounded-lg border-0 p-0.5 shadow-none">
              <TabsTrigger
                value="top"
                className="data-[state=active]:bg-accent data-[state=active]:text-foreground data-[state=inactive]:text-muted-foreground data-[state=inactive]:hover:text-foreground border-0 px-3 py-1.5 text-sm font-medium shadow-none data-[state=active]:shadow-none"
              >
                Top
              </TabsTrigger>
              <TabsTrigger
                value="new"
                className="data-[state=active]:bg-accent data-[state=active]:text-foreground data-[state=inactive]:text-muted-foreground data-[state=inactive]:hover:text-foreground border-0 px-3 py-1.5 text-sm font-medium shadow-none data-[state=active]:shadow-none"
              >
                New
              </TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        {sortedCards.length === 0 ? (
          <div className="py-6 text-center">
            <p className="text-muted-foreground/60 text-xs">
              Nothing here yet. Check back soon!
            </p>
          </div>
        ) : (
          <div className="flex flex-col">
            {sortedCards.map((card, index) => (
              <FeedCard
                key={card.id}
                card={card}
                isLast={
                  index === sortedCards.length - 1 && !hasMoreByView[view]
                }
                isAdministrator={isAdministrator}
                onDelete={handleDeleteCard}
              />
            ))}

            <div ref={loadMoreRef} className="h-px" aria-hidden="true" />

            {isLoading && (
              <div className="flex items-center justify-center py-4">
                <svg
                  className="text-muted-foreground/50 h-4 w-4 animate-spin"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  />
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                  />
                </svg>
              </div>
            )}

            {!hasMoreByView[view] && sortedCards.length > 0 && (
              <div className="py-6 text-center">
                <p className="text-muted-foreground/60 text-xs">
                  You've seen everything.
                </p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
