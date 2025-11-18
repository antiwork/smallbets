import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "unread" ]
  static classes = [ "unread" ]

  connect() {
    onNextEventLoopTick(() => this.update())
  }

  update() {
    if (this.#available) {
      const unreadCount = this.#unreadCount

      if (unreadCount > 0) {
        navigator.setAppBadge(unreadCount)
      } else {
        navigator.clearAppBadge()
      }
    }
  }

  get #unreadCount() {
    return this.unreadTargets.filter(unreadTarget => unreadTarget.classList.contains(this.unreadClass)).length
  }

  get #available() {
    return "setAppBadge" in navigator
  }
}
