import { useEffect, useState } from "react"

/**
 * Hook to compute the number of visible shelf items based on current breakpoint.
 * Matches the Tailwind breakpoints used in the shelf layout:
 * - base: 2 items
 * - md (768px): 3 items
 * - lg (1024px): 4 items
 * - xl (1280px): 5 items
 * - 2xl (1536px): 6 items
 */
export function useShelfItems(): number {
  const [itemCount, setItemCount] = useState(2)

  useEffect(() => {
    const queries = [
      { media: "(min-width: 1536px)", count: 6 }, // 2xl
      { media: "(min-width: 1280px)", count: 5 }, // xl
      { media: "(min-width: 1024px)", count: 4 }, // lg
      { media: "(min-width: 768px)", count: 3 }, // md
      { media: "(min-width: 0px)", count: 2 }, // base
    ]

    function updateItemCount() {
      for (const { media, count } of queries) {
        if (window.matchMedia(media).matches) {
          setItemCount(count)
          return
        }
      }
    }

    updateItemCount()

    const mediaQueryLists = queries.map(({ media }) => window.matchMedia(media))
    mediaQueryLists.forEach((mql) => {
      // Safari < 14 fallback
      if ("addEventListener" in mql) {
        mql.addEventListener("change", updateItemCount)
      } else if ("addListener" in mql) {
        // @ts-expect-error older Safari
        mql.addListener(updateItemCount)
      }
    })

    return () => {
      mediaQueryLists.forEach((mql) => {
        if ("removeEventListener" in mql) {
          mql.removeEventListener("change", updateItemCount)
        } else if ("removeListener" in mql) {
          // @ts-expect-error older Safari
          mql.removeListener(updateItemCount)
        }
      })
    }
  }, [])

  return itemCount
}
