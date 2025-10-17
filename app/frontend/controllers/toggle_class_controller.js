import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["toggle"]
  static values = {
    closeOnEscape: Boolean,
    focusTrap: Boolean,
    initialFocusSelector: String,
  }

  connect() {
    this._handleDocumentPointer = (event) => this.#handleDocumentPointer(event)
    document.addEventListener("mousedown", this._handleDocumentPointer)
    document.addEventListener("touchstart", this._handleDocumentPointer, {
      passive: true,
    })

    this._handleKeydown = (event) => this.#handleKeydown(event)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("mousedown", this._handleDocumentPointer)
    document.removeEventListener("touchstart", this._handleDocumentPointer)
    document.removeEventListener("keydown", this._handleKeydown)
  }

  toggle() {
    this.element.classList.toggle(this.toggleClass)
    // When opening, move focus to initial target inside
    if (this.element.classList.contains(this.toggleClass)) {
      if (this.focusTrapValue) this.#focusInitial()
    }
  }

  #handleDocumentPointer(event) {
    // Only apply outside-to-close on Library desktop overlay
    if (!this.#isLibraryDesktop()) return
    if (!this.element.classList.contains(this.toggleClass)) return
    if (this.element.contains(event.target)) return

    this.element.classList.remove(this.toggleClass)
  }

  #handleKeydown(event) {
    const isOpen = this.element.classList.contains(this.toggleClass)
    if (event.key === "Escape") {
      if (!this.closeOnEscapeValue || !isOpen) return
      this.element.classList.remove(this.toggleClass)
      if (this.element.id === "sidebar") {
        const toggle = document.getElementById("sidebar-toggle")
        if (toggle) toggle.focus()
      }
      return
    }

    if (event.key !== "Tab") return
    if (!this.focusTrapValue || !isOpen) return
    const focusables = this.#focusableWithin()
    if (focusables.length === 0) return
    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    const active = document.activeElement
    if (!this.element.contains(active)) {
      event.preventDefault()
      first.focus()
      return
    }
    if (event.shiftKey && active === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && active === last) {
      event.preventDefault()
      first.focus()
    }
  }

  #focusInitial() {
    const selector = this.hasInitialFocusSelectorValue
      ? this.initialFocusSelectorValue
      : undefined
    let target = selector
      ? this.element.querySelector(selector)
      : this.#focusableWithin()[0]
    if (!target && this.element.id === "sidebar") {
      target = this.element.querySelector("#room-search")
    }
    if (target && typeof target.focus === "function") {
      // Defer to next tick to respect any CSS transitions
      setTimeout(() => target.focus(), 0)
    }
  }

  #focusableWithin() {
    return Array.from(
      this.element.querySelectorAll(
        'a[href], area[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
      ),
    ).filter((el) => !el.hasAttribute("disabled") && el.tabIndex !== -1)
  }

  #isLibraryDesktop() {
    return (
      document.body.classList.contains("library-collapsed") &&
      window.matchMedia("(min-width: 120ch)").matches
    )
  }
}
