import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "loading"]

  load() {
    this.linkTarget.hidden = true
    this.loadingTarget.hidden = false
  }
}
