import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "dialog", "zoomedImage", "download", "share" ]

  connect() {
    this.scale = 1
    this.startDistance = 0
    this.#addTouchEvents()
  }

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    this.#set(event.target.closest("a"))
  }

  reset() {
    this.zoomedImageTarget.style.transform = "scale(1)" // reset zoom
    this.scale = 1
    this.zoomedImageTarget.src = ""
    this.downloadTarget.href = ""
    this.shareTarget.dataset.webShareFilesValue = ""
  }

  #set(target) {
    this.zoomedImageTarget.src = target.href
    this.downloadTarget.href = target.dataset.lightboxUrlValue
    this.shareTarget.dataset.webShareFilesValue = target.dataset.lightboxUrlValue
  }

  // --- private helpers ---
  #addTouchEvents() {
    this.zoomedImageTarget.addEventListener("touchstart", this.#onTouchStart, { passive: true })
    this.zoomedImageTarget.addEventListener("touchmove", this.#onTouchMove, { passive: true })
    this.zoomedImageTarget.addEventListener("touchend", this.#onTouchEnd, { passive: true })
  }

  #onTouchStart = (e) => {
    if (e.touches.length === 2) {
      this.startDistance = this.#getDistance(e.touches)
    }
  }

  #onTouchMove = (e) => {
    if (e.touches.length === 2) {
      const newDistance = this.#getDistance(e.touches)
      const zoom = newDistance / this.startDistance
      this.zoomedImageTarget.style.transform = `scale(${this.scale * zoom})`
    }
  }

  #onTouchEnd = (e) => {
    if (e.touches.length < 2) {
      // lock in current zoom
      const transform = window.getComputedStyle(this.zoomedImageTarget).transform
      if (transform !== "none") {
        const matrix = new DOMMatrix(transform)
        this.scale = matrix.a // current scale value
      }
    }
  }

  #getDistance(touches) {
    const dx = touches[0].pageX - touches[1].pageX
    const dy = touches[0].pageY - touches[1].pageY
    return Math.sqrt(dx * dx + dy * dy)
  }
}
