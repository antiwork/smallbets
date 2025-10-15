import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["toggle"]

  connect() {
    this._handleDocumentPointer = (event) => this.#handleDocumentPointer(event)
    document.addEventListener("mousedown", this._handleDocumentPointer)
    document.addEventListener("touchstart", this._handleDocumentPointer, {
      passive: true,
    })
  }

  disconnect() {
    document.removeEventListener("mousedown", this._handleDocumentPointer)
    document.removeEventListener("touchstart", this._handleDocumentPointer)
  }

  toggle() {
    this.element.classList.toggle(this.toggleClass)
  }

  #handleDocumentPointer(event) {
    // Only apply outside-to-close on Library desktop overlay
    if (!this.#isLibraryDesktop()) return
    if (!this.element.classList.contains(this.toggleClass)) return
    if (this.element.contains(event.target)) return

    this.element.classList.remove(this.toggleClass)
  }

  #isLibraryDesktop() {
    return (
      document.body.classList.contains("library-collapsed") &&
      window.matchMedia("(min-width: 120ch)").matches
    )
  }
}
