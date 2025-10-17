import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { "url": String }

  play() {
    const sound = new Audio(this.urlValue)
    sound.play()
  }
}
