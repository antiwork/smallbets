import { onNextEventLoopTick } from "helpers/timing_helpers"

const AUTO_SCROLL_THRESHOLD = 100

export default class ScrollManager {
  static #pendingOperations = Promise.resolve()

  #container
  #cachedScrollHeight = 0
  #cachedClientHeight = 0
  #rafId = null

  constructor(container) {
    this.#container = container
    this.#updateCache()
  }

  async autoscroll(forceScroll, render = () => {}) {
    return this.#appendOperation(async () => {
      const wasNearEnd = this.#scrolledNearEnd

      await render()
      
      // Update cache after render
      this.#updateCache()

      if (wasNearEnd || forceScroll) {
        this.#container.scrollTop = this.#container.scrollHeight
        return true
      } else {
        return false
      }
    })
  }

  async keepScroll(top, render, scrollBehaviour, delay) {
    return this.#appendOperation(async () => {
      const scrollTop = this.#container.scrollTop
      const scrollHeight = this.#cachedScrollHeight // Use cached value

      // Safari-specific: Temporarily disable scroll restoration
      const originalScrollRestoration = history.scrollRestoration
      if (history.scrollRestoration) {
        history.scrollRestoration = 'manual'
      }

      // Safari-specific: Force immediate scroll position lock
      const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent)
      if (isSafari && scrollTop > 0) {
        // Prevent Safari from jumping by setting a temporary fixed position
        const originalOverflow = this.#container.style.overflow
        this.#container.style.overflow = 'hidden'
        this.#container.style.scrollBehavior = 'auto'
        
        // Restore after a minimal delay to prevent the jump
        setTimeout(() => {
          this.#container.style.overflow = originalOverflow
        }, 0)
      }

      await render()
      
      // Update cache after render
      this.#updateCache()

      const newScrollTop = top ? scrollTop + (this.#container.scrollHeight - scrollHeight) : scrollTop
      
      // Safari-specific: Use multiple restoration attempts
      const restoreScroll = () => {
        this.#container.scrollTo({ top: newScrollTop, behavior: scrollBehaviour })
        
        // Safari sometimes needs a second attempt
        if (isSafari && Math.abs(this.#container.scrollTop - newScrollTop) > 1) {
          requestAnimationFrame(() => {
            this.#container.scrollTo({ top: newScrollTop, behavior: 'auto' })
          })
        }
      }
      
      if (delay) {
        requestAnimationFrame(restoreScroll)
      } else {
        restoreScroll()
      }

      // Restore scroll restoration setting
      if (originalScrollRestoration) {
        setTimeout(() => {
          history.scrollRestoration = originalScrollRestoration
        }, 100)
      }
    })
  }

  // Private

  #appendOperation(operation) {
    ScrollManager.#pendingOperations =
      ScrollManager.#pendingOperations.then(operation)
    return ScrollManager.#pendingOperations
  }
  
  #updateCache() {
    // Cancel any pending RAF to avoid duplicates
    if (this.#rafId) {
      cancelAnimationFrame(this.#rafId)
    }
    
    // Use requestAnimationFrame to batch layout reads
    this.#rafId = requestAnimationFrame(() => {
      this.#cachedScrollHeight = this.#container.scrollHeight
      this.#cachedClientHeight = this.#container.clientHeight
      this.#rafId = null
    })
  }

  get #scrolledNearEnd() {
    return this.#distanceScrolledFromEnd <= AUTO_SCROLL_THRESHOLD
  }

  get #distanceScrolledFromEnd() {
    // Use cached values to avoid forced reflow
    // scrollTop is cheap to read and changes frequently, so we don't cache it
    return this.#cachedScrollHeight - this.#container.scrollTop - this.#cachedClientHeight
  }
}
