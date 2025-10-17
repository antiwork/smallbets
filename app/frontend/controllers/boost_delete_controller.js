import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "reveal", "perform" ]
  static targets = [ "button", "content" ]
  static values = { boosterId: Number }

  connect() {
    if (this.#currentUserIsBooster) {
      this.#setAccessibleAttributes()
    }
  }

  reveal({ srcElement }) {
    // Can't rely on regular event.stopPropagation as it's needed for Turbo
    if (srcElement.closest('[data-stop-propagation]')) return;
    
    if (this.#currentUserIsBooster) {
      this.element.classList.toggle(this.revealClass)
      this.buttonTarget.focus()
    }
  }

  perform() {
    this.element.classList.add(this.performClass)
  }

  #setAccessibleAttributes() {
    this.contentTarget.setAttribute('tabindex', '0')
    this.contentTarget.setAttribute('aria-describedby', 'delete_boost_accessible_label')
  }

  get #currentUserIsBooster() {
    return Current.user.id === this.boosterIdValue
  }
}
