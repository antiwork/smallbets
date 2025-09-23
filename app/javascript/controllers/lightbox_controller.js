import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "dialog", "zoomedImage", "download", "share" ]

  connect() {
    this.scale = 1
    this.startDistance = 0
    this.activePointers = new Map()
    this.translation = { x: 0, y: 0 }
    this.startTranslation = { x: 0, y: 0 }
    this.lastMidpoint = null
    this.#addPointerEvents()
  }

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    this.#set(event.target.closest("a"))
  }

  reset() {
    this.scale = 1
    this.translation = { x: 0, y: 0 }
    this.startDistance = 0
    this.activePointers.clear()
    this.#applyTransform()
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
  #addPointerEvents() {
    this.zoomedImageTarget.style.touchAction = "none"

    this.zoomedImageTarget.addEventListener("pointerdown", this.#onPointerDown)
    this.zoomedImageTarget.addEventListener("pointermove", this.#onPointerMove)
    this.zoomedImageTarget.addEventListener("pointerup", this.#onPointerUp)
    this.zoomedImageTarget.addEventListener("pointercancel", this.#onPointerUp)
    this.zoomedImageTarget.addEventListener("pointerout", this.#onPointerUp)
    this.zoomedImageTarget.addEventListener("pointerleave", this.#onPointerUp)
  }

  #onPointerDown = (e) => {
    this.activePointers.set(e.pointerId, e)

    if (this.activePointers.size === 2) {
      const [p1, p2] = Array.from(this.activePointers.values())
      this.startDistance = this.#getDistance(p1, p2)
      this.lastMidpoint = this.#getMidpoint(p1, p2)
      this.startTranslation = { ...this.translation }
    } else if (this.activePointers.size === 1 && this.scale > 1) {
      // for dragging with one finger
      const p = e
      this.lastMidpoint = { x: p.clientX, y: p.clientY }
      this.startTranslation = { ...this.translation }
    }
  }

  #onPointerMove = (e) => {
    if (!this.activePointers.has(e.pointerId)) return
    this.activePointers.set(e.pointerId, e)

    if (this.activePointers.size === 2) {
      // Pinch zoom
      const [p1, p2] = Array.from(this.activePointers.values())
      const newDistance = this.#getDistance(p1, p2)
      const zoomFactor = newDistance / this.startDistance
      const newScale = this.scale * zoomFactor

      // Midpoint between fingers
      const midpoint = this.#getMidpoint(p1, p2)

      // Adjust translation so zoom happens around the midpoint
      this.translation.x = this.startTranslation.x + (midpoint.x - this.lastMidpoint.x) + (1 - zoomFactor) * (midpoint.x - this.zoomedImageTarget.clientWidth / 2)
      this.translation.y = this.startTranslation.y + (midpoint.y - this.lastMidpoint.y) + (1 - zoomFactor) * (midpoint.y - this.zoomedImageTarget.clientHeight / 2)

      this.#applyTransform(newScale)
    } else if (this.activePointers.size === 1 && this.scale > 1) {
      // Drag when zoomed
      const p = e
      const dx = p.clientX - this.lastMidpoint.x
      const dy = p.clientY - this.lastMidpoint.y
      this.translation.x = this.startTranslation.x + dx
      this.translation.y = this.startTranslation.y + dy
      this.#applyTransform()
    }
  }

  #onPointerUp = (e) => {
    this.activePointers.delete(e.pointerId)
    if (this.activePointers.size === 0) {
      // lock scale + translation
      const transform = window.getComputedStyle(this.zoomedImageTarget).transform
      if (transform !== "none") {
        const matrix = new DOMMatrix(transform)
        this.scale = matrix.a
        this.translation.x = matrix.e
        this.translation.y = matrix.f
      }
    }
  }

  #getDistance(p1, p2) {
    const dx = p1.clientX - p2.clientX
    const dy = p1.clientY - p2.clientY
    return Math.sqrt(dx * dx + dy * dy)
  }

  #getMidpoint(p1, p2) {
    return { x: (p1.clientX + p2.clientX) / 2, y: (p1.clientY + p2.clientY) / 2 }
  }

  #applyTransform(scale = this.scale) {
    this.zoomedImageTarget.style.transform = `translate(${this.translation.x}px, ${this.translation.y}px) scale(${scale})`
  }
}
