import { Controller } from "@hotwired/stimulus"

const VIMEO_ORIGIN = "https://player.vimeo.com"
const TRACKED_EVENTS = ["play", "pause", "timeupdate", "ended"]

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    videoId: String,
    reportUrl: String
  }

  connect() {
    this.boundMessageHandler = event => this.#handleMessage(event)
    window.addEventListener("message", this.boundMessageHandler)
    this.#postMessage({ method: "ping" })
  }

  disconnect() {
    if (this.boundMessageHandler) {
      window.removeEventListener("message", this.boundMessageHandler)
    }
  }
  #handleMessage(event) {
    if (!this.#isVimeoEvent(event)) return

    const data = this.#normalizeData(event.data)
    if (!data) return

    if (data.event === "ready") {
      this.#subscribeToEvents()
      return
    }

    if (TRACKED_EVENTS.includes(data.event)) {
      this.#recordPlaybackEvent(data.event, data.data)
    }
  }

  #subscribeToEvents() {
    TRACKED_EVENTS.forEach(eventName => {
      this.#postMessage({ method: "addEventListener", value: eventName })
    })
  }

  #recordPlaybackEvent(name, payload = {}) {
    if (!this.hasReportUrlValue) return

    const body = JSON.stringify({
      event: name,
      videoId: this.videoIdValue,
      payload
    })

    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: "application/json" })
      navigator.sendBeacon(this.reportUrlValue, blob)
      return
    }

    fetch(this.reportUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body
    }).catch(() => {
      // Silently ignore network failures for now; server wiring will handle retries.
    })
  }

  #postMessage(message) {
    const frame = this.frameTarget
    if (!frame?.contentWindow) return

    frame.contentWindow.postMessage(message, VIMEO_ORIGIN)
  }

  #isVimeoEvent(event) {
    if (event.origin !== VIMEO_ORIGIN) return false
    if (event.source !== this.frameTarget.contentWindow) return false
    return true
  }

  #normalizeData(data) {
    if (!data) return null

    if (typeof data === "string") {
      try {
        return JSON.parse(data)
      } catch (error) {
        return null
      }
    }

    if (typeof data === "object") {
      return data
    }

    return null
  }
}
