import { Controller } from "@hotwired/stimulus"
import panzoom from "panzoom"

export default class extends Controller {
  static targets = [ "image", "dialog", "zoomedImage", "download", "share" ]

  open(event) {
    event.preventDefault()

    this.dialogTarget.showModal()
    this.#set(event.target.closest("a"))

    // Initialize panzoom on the zoomed image
    if (this._panzoomInstance) {
      this._panzoomInstance.dispose && this._panzoomInstance.dispose();
      this._panzoomInstance = null;
    }
    this._panzoomInstance = panzoom(this.zoomedImageTarget, {
      maxZoom: 5,
      minZoom: 1,
      bounds: true,
      boundsPadding: 0.9,
      zoomDoubleClickSpeed: 1.5
      // Pinch-to-zoom is enabled by default on touch devices
    });
  }

  reset() {
    this.zoomedImageTarget.src = ""
    this.downloadTarget.href = ""
    this.shareTarget.dataset.webShareFilesValue = "";
    // Dispose panzoom instance when closing
    if (this._panzoomInstance) {
      this._panzoomInstance.dispose && this._panzoomInstance.dispose();
      this._panzoomInstance = null;
    }
  }

  #set(target) {
    this.zoomedImageTarget.src = target.href
    this.downloadTarget.href = target.dataset.lightboxUrlValue;
    this.shareTarget.dataset.webShareFilesValue = target.dataset.lightboxUrlValue;
  }
}
