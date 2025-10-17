import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { title: String, text: String, url: String, files: String }

  connect() {
    this.element.hidden = !navigator.canShare
  }

  async share() {
    await navigator.share(await this.#getShareData())
  }

  async #getShareData() {
    const data = { title: this.titleValue, text: this.textValue }

    if (this.urlValue) {
      data.url = this.urlValue
    }

    if (this.filesValue) {
      data.files = [ await this.#getFileObject()]
    }

    return data;
  }

  async #getFileObject() {
    const response = await fetch(this.filesValue)
    const blob = await response.blob()
    const randomPrefix = `Campfire_${Math.random().toString(36).slice(2)}`
    const fileName = `${randomPrefix}.${blob.type.split('/').pop()}`

    return new File([ blob ], fileName, { type: blob.type })
  }
}
