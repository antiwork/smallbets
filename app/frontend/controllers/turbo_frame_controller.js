import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  unpermanize() {
    delete this.element.dataset.turboPermanent
  }

  reload() {
    this.element.reload()
  }

  load({ params: { url }}) {
    onNextEventLoopTick(() => this.element.src = url)
  }
}
