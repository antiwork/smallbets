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

      await render()
      
      // Update cache after render
      this.#updateCache()

      const newScrollTop = top ? scrollTop + (this.#container.scrollHeight - scrollHeight) : scrollTop
      
      if (delay) {
        requestAnimationFrame(() => this.#container.scrollTo({ top: newScrollTop, behavior: scrollBehaviour }))
      } else {
        this.#container.scrollTo({ top: newScrollTop, behavior: scrollBehaviour })
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
