import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dragenter(event) {
    event.preventDefault()
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  drop(event) {
    event.preventDefault()
    this.dispatch("drop", { detail: { files: event.dataTransfer.files }})
  }
}
