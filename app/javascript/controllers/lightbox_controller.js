import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "dialog", "zoomedImage", "download", "share" ]

  open(event) {
    event.preventDefault()

    this.dialogTarget.showModal()
    this.#set(event.target.closest("a"))
    this.#toggleViewportZoom(true)
  }

  reset() {
    this.zoomedImageTarget.src = ""
    this.downloadTarget.href = ""
    this.shareTarget.dataset.webShareFilesValue = "";
    this.#toggleViewportZoom(false)
  }

  #set(target) {
    this.zoomedImageTarget.src = target.href
    this.downloadTarget.href = target.dataset.lightboxUrlValue;
    this.shareTarget.dataset.webShareFilesValue = target.dataset.lightboxUrlValue;
  }

  #toggleViewportZoom(allowZoom) {
    const viewportMeta = document.querySelector('meta[name="viewport"]')

    if (viewportMeta) {
      if (allowZoom) {
        this.originalViewportContent = viewportMeta.content
        viewportMeta.content = this.originalViewportContent.replace(/user-scalable=(no|0)/, "user-scalable=yes")
      } else if (this.originalViewportContent) {
        viewportMeta.content = this.originalViewportContent
      }
    }
  }
}
