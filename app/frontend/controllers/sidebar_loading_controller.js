import { Controller } from "@hotwired/stimulus"

/**
 * Controls the loading state of the sidebar.
 * Shows a loading spinner while the sidebar content is being loaded,
 * then transitions to showing the content once ready.
 */
export default class extends Controller {
  static targets = ["spinner", "content"]
  static values = { loaded: Boolean }

  connect() {
    // Check if content is already loaded (turbo cache hit)
    if (this.hasContentTarget && this.contentTarget.children.length > 0) {
      this.showContent()
    }
  }

  showContent() {
    this.loadedValue = true
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = true
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove("sidebar--loading")
    }
  }

  frameLoaded() {
    // Called when the turbo frame finishes loading
    this.showContent()
  }
}
