import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { src: String, loaded: Boolean }

  connect() {
    this.loadedValue = false
  }

  load() {
    if (this.loadedValue) return

    const frame = this.element
    if (this.srcValue && !frame.src) {
      frame.src = this.srcValue
      this.loadedValue = true
    }
  }
}
