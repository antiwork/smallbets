export interface LibraryCategoryPayload {
  id: number
  name: string
  slug: string
}

export interface LibraryWatchPayload {
  playedSeconds: number
  durationSeconds?: number | null
  lastWatchedAt?: string | null
  completed: boolean
}

export interface LibrarySessionPayload {
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

export interface LibraryLayoutPayload {
  pageTitle?: string
  bodyClass?: string
  nav?: string
  sidebar?: string
}

export interface VimeoThumbnailPayload {
  id: string
  src: string
  srcset: string
  width: number
  height: number
}
