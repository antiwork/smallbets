import { Controller } from "@hotwired/stimulus"
import ScrollManager from "models/scroll_manager"

export default class extends Controller {
  #scrollManager
  #isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent)

  connect() {
    this.#scrollManager = new ScrollManager(this.element)
    
    // Safari-specific: Add additional scroll jump prevention
    if (this.#isSafari) {
      this.#preventSafariScrollJump()
    }
  }

  // Actions

  beforeStreamRender(event) {
    const shouldKeepScroll = event.detail.newStream.hasAttribute("maintain_scroll")
    const render = event.detail.render
    const target = event.detail.newStream.getAttribute("target")
    const targetElement = document.getElementById(target)

    if (this.element.contains(targetElement) && shouldKeepScroll) {
      const top = this.#isAboveFold(targetElement)
      event.detail.render = async (streamElement) => {
        this.#scrollManager.keepScroll(top, () => render(streamElement), 'auto')
      }
    }
  }

  beforeRender(event) {
    const render = event.detail.render

    event.detail.render = async (...args) => {
      this.#scrollManager.keepScroll(false, () => render(...args), 'instant', true)
    }
  }

  // Internal

  #isAboveFold(element) {
    return element.getBoundingClientRect().top < this.element.clientHeight
  }

  #preventSafariScrollJump() {
    // Safari-specific: Prevent scroll jumping during Turbo Stream updates
    this.element.addEventListener('turbo:before-stream-render', (event) => {
      if (this.element.scrollTop > 0) {
        // Store current scroll position
        const currentScrollTop = this.element.scrollTop
        
        // Temporarily lock scroll position
        this.element.style.scrollBehavior = 'auto'
        
        // Restore scroll position after DOM update
        requestAnimationFrame(() => {
          if (Math.abs(this.element.scrollTop - currentScrollTop) > 5) {
            this.element.scrollTop = currentScrollTop
          }
          // Reset scroll behavior
          this.element.style.scrollBehavior = ''
        })
      }
    })

    // Additional Safari fix for room navigation
    this.element.addEventListener('turbo:render', () => {
      if (this.element.scrollTop > 0) {
        // Force scroll position stability after render
        const scrollTop = this.element.scrollTop
        setTimeout(() => {
          if (this.element.scrollTop !== scrollTop) {
            this.element.scrollTo({ top: scrollTop, behavior: 'auto' })
          }
        }, 0)
      }
    })
  }
}
