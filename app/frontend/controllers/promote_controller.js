import { Controller } from "@hotwired/stimulus"

const EVENT_NAME = "toast:show"

export default class extends Controller {
  connect() {
    this.form = this.element.closest("form")
    if (!this.form) return

    this.handleSubmit = this.handleSubmit.bind(this)
    this.form.addEventListener("turbo:submit-start", this.handleSubmit)
  }

  disconnect() {
    if (!this.form || !this.handleSubmit) return

    this.form.removeEventListener("turbo:submit-start", this.handleSubmit)
    this.form = null
  }

  handleSubmit() {
    window.dispatchEvent(
      new CustomEvent(EVENT_NAME, {
        detail: {
          type: "success",
          message: "Promoted to Home",
        },
      }),
    )
  }
}
