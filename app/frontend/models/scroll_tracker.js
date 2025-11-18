const SCROLLED_AWAY_FROM_LATEST_THRESHOLD = 500

export default class ScrollTracker {
    #container
    #lastChildRevealedCallback
    #lastChildHiddenCallback
    #intersectionObserver
    #mutationObserver
    #firstChildWasHidden
    #cachedScrollHeight = 0
    #cachedClientHeight = 0
    #rafId = null

    constructor(container, { lastChildRevealed, lastChildHidden }) {
        this.#container = container
        this.#lastChildRevealedCallback = lastChildRevealed
        this.#lastChildHiddenCallback = lastChildHidden

        this.#mutationObserver = new MutationObserver(this.#childrenChanged.bind(this))
        this.#mutationObserver.observe(container, {childList: true})

        this.#intersectionObserver = new IntersectionObserver(this.#handleIntersection.bind(this), {root: container})
        
        // Initialize cached values
        this.#updateCachedValues()
    }

    connect() {
        this.#childrenChanged()
    }

    disconnect() {
        this.#intersectionObserver?.disconnect()
        if (this.#rafId) {
            cancelAnimationFrame(this.#rafId)
            this.#rafId = null
        }
    }

    #childrenChanged() {
        this.disconnect()

        if (this.#container.firstElementChild) {
            this.#firstChildWasHidden = false

            this.#intersectionObserver?.observe(this.#container.firstElementChild)
            this.#intersectionObserver?.observe(this.#container.lastElementChild)
        }
        
        // Update cached values when DOM changes
        this.#updateCachedValues()
    }
    
    #updateCachedValues() {
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

    #handleIntersection(entries) {
        for (const entry of entries) {
            // Don't callback when the first child is shown, unless it had previously
            // been hidden. This avoids the issue that adding new pages will always
            // fire the callback for the first item before the scroll position is
            // adjusted.
            //
            // We don't do this with the last item, because it's possible that
            // fetching a page could return less than a screenfull.
            const isFirst = entry.target === this.#container.firstElementChild
            const significantReveal = (isFirst && this.#firstChildWasHidden) || !isFirst

            if (entry.isIntersecting) {
                if (significantReveal) {
                    this.#lastChildRevealedCallback?.(entry.target)
                }
            } else {
                if (isFirst) {
                    this.#firstChildWasHidden = true
                } else {
                    this.#lastChildHiddenCallback?.()
                }
            }
        }
    }

    get scrolledFarFromLatest() {
        return this.#distanceScrolledFromEnd > SCROLLED_AWAY_FROM_LATEST_THRESHOLD
    }

    get #distanceScrolledFromEnd() {
        // Use cached values to avoid forced reflow
        // scrollTop is cheap to read and changes frequently, so we don't cache it
        return this.#cachedScrollHeight - this.#container.scrollTop - this.#cachedClientHeight
    }
}