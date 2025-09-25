import { Controller } from "@hotwired/stimulus"

// This controller debounces Turbo Stream updates to prevent race conditions.
// It works by tracking the timestamp of the last update for each room
// and ignoring any updates that are older than the last one received.
export default class extends Controller {
  static values = {
    timestamps: { type: Object, default: {} }
  }

  connect() {
    this.boundDebounce = this.debounce.bind(this)
    this.element.addEventListener("turbo:before-stream-render", this.boundDebounce)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-stream-render", this.boundDebounce)
  }

  debounce(event) {
    const newElement = event.detail.newStream.template.content.firstElementChild
    if (!newElement?.dataset.updatedAt) {
      return
    }

    const targetId = event.target.target
    const roomId = this.getRoomId(targetId)
    if (!roomId) {
      return
    }

    const newTimestamp = new Date(newElement.dataset.updatedAt).getTime()
    const lastTimestamp = this.timestampsValue[roomId] || 0

    if (newTimestamp >= lastTimestamp) {
      this.timestampsValue = { ...this.timestampsValue, [roomId]: newTimestamp }
    } else {
      // Stop the rendering if the incoming update is older
      event.preventDefault()
    }
  }

  getRoomId(targetId) {
    const match = targetId.match(/^room_(\d+)/)
    return match ? match[1] : null
  }
}
