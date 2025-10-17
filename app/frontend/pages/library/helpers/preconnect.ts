// Lightweight preconnect utility for Vimeo domains

const PRECONNECT_ORIGINS = [
  "https://player.vimeo.com",
  "https://i.vimeocdn.com",
  "https://f.vimeocdn.com",
]

const preconnected = new Set<string>()

function addPreconnect(origin: string): void {
  if (typeof document === "undefined") return
  if (preconnected.has(origin)) return
  const existing = document.head.querySelector<HTMLLinkElement>(
    `link[rel="preconnect"][href="${origin}"]`,
  )
  if (existing) {
    preconnected.add(origin)
    return
  }
  const link = document.createElement("link")
  link.rel = "preconnect"
  link.href = origin
  link.crossOrigin = "anonymous"
  document.head.appendChild(link)
  preconnected.add(origin)
}

export function preconnectVimeo(): void {
  PRECONNECT_ORIGINS.forEach(addPreconnect)
}

let hasPreconnected = false
export function preconnectVimeoOnce(): void {
  if (hasPreconnected) return
  hasPreconnected = true
  preconnectVimeo()
}
