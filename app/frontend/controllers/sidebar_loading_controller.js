import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    // Hide loading indicator if content is already loaded
    if (this.hasIndicatorTarget && this.element.querySelector(".sidebar__container")) {
      this.hide()
    }
  }

  show() {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.style.display = "flex"
    }
  }

  hide() {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.style.display = "none"
    }
  }
}
