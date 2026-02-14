import { Controller } from "@hotwired/stimulus"

/**
 * Lazy loads involvement buttons when the user hovers over a room item.
 * This reduces initial page load time by deferring the rendering of
 * involvement buttons until they're actually needed.
 */
export default class extends Controller {
  static targets = ["trigger", "frame"]
  static values = { loaded: Boolean, src: String }

  connect() {
    this.loadedValue = false
  }

  load() {
    if (this.loadedValue || !this.hasSrcValue) return

    this.loadedValue = true

    if (this.hasFrameTarget) {
      this.frameTarget.src = this.srcValue
    }
  }

  // Also load on focus for keyboard accessibility
  loadOnFocus() {
    this.load()
  }
}
