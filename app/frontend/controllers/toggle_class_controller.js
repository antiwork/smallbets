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

    this._handleSkipToMenu = (event) => {
      if (!document.body.classList.contains("library-collapsed")) return
      const anchor = event.currentTarget
      if (!(anchor instanceof HTMLAnchorElement)) return
      if (anchor.getAttribute("href") !== "#sidebar-toggle") return
      event.preventDefault()
      if (!this.element.classList.contains(this.toggleClass)) {
        this.element.classList.add(this.toggleClass)
      }
      if (this.focusTrapValue) this.#focusInitial()
    }

    const skipToMenu = document.querySelector(
      'a.skip-navigation[href="#sidebar-toggle"]',
    )
    if (skipToMenu) skipToMenu.addEventListener("click", this._handleSkipToMenu)

    // Close sidebar on mobile when navigating to a new page
    this._handleTurboClick = (event) => this.#handleTurboClick(event)
    document.addEventListener("turbo:click", this._handleTurboClick)
  }

  disconnect() {
    document.removeEventListener("mousedown", this._handleDocumentPointer)
    document.removeEventListener("touchstart", this._handleDocumentPointer)
    document.removeEventListener("keydown", this._handleKeydown)
    document.removeEventListener("turbo:click", this._handleTurboClick)
    const skipToMenu = document.querySelector(
      'a.skip-navigation[href="#sidebar-toggle"]',
    )
    if (skipToMenu)
      skipToMenu.removeEventListener("click", this._handleSkipToMenu)
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
        // On Library overlay, return focus to main content for better a11y
        if (document.body.classList.contains("library-collapsed")) {
          const main = document.getElementById("main-content")
          if (main && typeof main.focus === "function") main.focus()
        } else {
          // Fallback to the sidebar toggle elsewhere
          const toggle = document.getElementById("sidebar-toggle")
          if (toggle) toggle.focus()
        }
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

  #handleTurboClick(event) {
    // On mobile (max-width: 120ch), close the sidebar when clicking a link inside it
    // This ensures the user sees the room content after selecting it
    if (window.matchMedia("(min-width: 120ch)").matches) return
    if (!this.element.classList.contains(this.toggleClass)) return

    // Check if the clicked element is a link inside the sidebar
    const target = event.target
    const link = target.closest("a[href]")
    if (!link) return
    if (!this.element.contains(link)) return

    // Close the sidebar
    this.element.classList.remove(this.toggleClass)
  }
}
