import { Controller } from "@hotwired/stimulus"
import ScrollManager from "models/scroll_manager"

export default class extends Controller {
  #scrollManager

  connect() {
    this.#scrollManager = new ScrollManager(this.element)
  }

  // Actions

  beforeStreamRender(event) {
    const shouldKeepScroll = event.detail.newStream.hasAttribute("maintain_scroll")
    const render = event.detail.render
    const target = event.detail.newStream.getAttribute("target")
    const targetElement = document.getElementById(target)

    if (this.element.contains(targetElement) && shouldKeepScroll) {
      const top = this.#isAboveFold(targetElement)
      event.detail.render = async (streamElement) => {
        this.#scrollManager.keepScroll(top, () => render(streamElement), 'auto')
      }
    }
  }

  beforeRender(event) {
    const render = event.detail.render

    event.detail.render = async (...args) => {
      this.#scrollManager.keepScroll(false, () => render(...args), 'instant', true)
    }
  }

  // Internal

  #isAboveFold(element) {
    return element.getBoundingClientRect().top < this.element.clientHeight
  }
}
