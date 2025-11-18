import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
import { cable } from "@hotwired/turbo-rails"
import { pageIsTurboPreview } from "helpers/turbo_helpers"

const OFFLINE_AFTER_DISCONNECTED_TIMEOUT = 5_000
const REFRESH_AFTER_HIDDEN_TIMEOUT = 60_000

export default class extends Controller {
  static targets = [ "message" ]
  static classes = [ "firstUnread" ]
  static values = { loadedAt: Number, url: String, }

  #lastLoadedAt
  #offlineTimer = null
  #hiddenAt = null

  async connect() {
    if (!pageIsTurboPreview()) {
      this.#lastLoadedAt = this.loadedAtValue
      this.#channelDisconnected()

      this.channel = await cable.subscribeTo({ channel: "HeartbeatChannel" }, {
        connected: this.#channelConnected.bind(this),
        disconnected: this.#channelDisconnected.bind(this)
      })
    }
  }

  disconnect() {
    this.channel?.unsubscribe()
  }

  messageTargetConnected(target) {
    this.#lastLoadedAt = Math.max(this.#lastLoadedAt, target.dataset.messageUpdatedAt || 0)
  }

  visibilityChanged() {
    if (document.visibilityState === "visible") {
      if (this.#hiddenForTooLong()) {
        this.#refresh("visibility")
        this.dispatch("visible")
      }
      this.#hiddenAt = null
    } else {
      this.#hiddenAt = Date.now()
    }
  }

  online() {
    // Trigger reconnection attempt whenever the browser comes back
    // from being offline
    this.channel.consumer.connection.monitor.visibilityDidChange()
  }

  #channelConnected() {
    this.#refresh("connection")

    clearTimeout(this.#offlineTimer)
    this.dispatch("online", { target: window })
  }

  #channelDisconnected() {
    this.#offlineTimer = setTimeout(() => {
      this.dispatch("offline", { target: window })
    }, OFFLINE_AFTER_DISCONNECTED_TIMEOUT)
  }

  #refresh(reason) {
    get(this.urlValue, { query: { since: this.#lastLoadedAt, reason: reason, unread_at_message_id: this.#unreadAtMessageId || "" }, responseKind: "turbo-stream" })
  }

  #hiddenForTooLong() {
    return this.#hiddenAt && Date.now() - this.#hiddenAt > REFRESH_AFTER_HIDDEN_TIMEOUT
  }

  get #unreadAtMessageId() {
    const firstUnreadMessage = this.messageTargets.find((element) =>
        element.querySelector(`.${this.firstUnreadClass}`)
    )
    return firstUnreadMessage?.dataset?.messageId
  }
}
