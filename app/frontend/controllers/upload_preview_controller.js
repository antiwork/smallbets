import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "input" ]

  previewImage() {
    const file = this.inputTarget.files[0]

    if (file) {
      this.imageTarget.src = URL.createObjectURL(this.inputTarget.files[0]);
      this.imageTarget.onload = () => { URL.revokeObjectURL(this.imageTarget.src) }
    }
  }
}
