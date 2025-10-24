import { useEffect } from "react"

interface IntersectionStopOptions<T extends HTMLElement> {
  containerRef: React.RefObject<T | null>
  onOutOfView: () => void
}

export function useIntersectionStop<T extends HTMLElement>({
  containerRef,
  onOutOfView,
}: IntersectionStopOptions<T>) {
  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    if (typeof window === "undefined") return
    if (!("IntersectionObserver" in window)) return
    const observer = new IntersectionObserver((entries) => {
      const entry = entries[0]
      if (!entry) return
      if (!entry.isIntersecting) onOutOfView()
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [containerRef, onOutOfView])
}
