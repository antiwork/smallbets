import { Controller } from "@hotwired/stimulus"

const BOTTOM_THRESHOLD = 90

export default class extends Controller {
  static targets = [ "menu" ]
  static classes = [ "orientationTop" ]

  close() {
    this.element.open = false
  }

  toggle() {
    this.#orient()
    
    // Load turbo frame only when popup opens
    if (this.element.open) {
      const frame = this.menuTarget.querySelector('turbo-frame[data-turbo-frame-src]')
      if (frame && !frame.hasAttribute('src')) {
        // Set src from data attribute to trigger loading
        frame.src = frame.dataset.turboFrameSrc
        // Remove the data attribute to prevent re-loading
        delete frame.dataset.turboFrameSrc
      }
    }
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  #orient() {
    this.element.classList.toggle(this.orientationTopClass, this.#distanceToBottom < BOTTOM_THRESHOLD)
    this.menuTarget.style.setProperty("--max-width", this.#maxWidth + "px")
  }

  get #distanceToBottom() {
    return window.innerHeight - this.#boundingClientRect.bottom
  }

  get #maxWidth() {
    return window.innerWidth - this.#boundingClientRect.left
  }

  get #boundingClientRect() {
    return this.menuTarget.getBoundingClientRect()
  }
}
