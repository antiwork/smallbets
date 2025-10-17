import { generateUUID, synchronize } from "lib/autocomplete/helpers"

export default class extends HTMLElement {
  constructor() {
    super(...arguments)
    this.flash = synchronize(this.flash)
  }

  connectedCallback() {
    this.id ||= `option-${generateUUID()}`
  }

  get selectElement() {
    return this.closest("suggestion-select")
  }

  get index() {
    if (this.selectElement) {
      return Array.from(this.selectElement.optionElements).indexOf(this)
    } else {
      return null
    }
  }

  get selected() {
    return this.hasAttribute("selected")
  }

  set selected(value) {
    if (value) {
      this.setAttribute("selected", "")
    } else {
      this.removeAttribute("selected")
    }
  }

  get value() {
    return this.getAttribute("value")
  }

  flash(callback) {
    const drawFrame = (frame = 0) => {
      requestAnimationFrame(() => {
        if (frame == 0) {
          this.classList.add("flashing-off")
        } else if (frame == 4) {
          this.classList.remove("flashing-off")
        }

        if (frame == 7) {
          callback()
        } else {
          drawFrame(frame + 1)
        }
      })
    }
    drawFrame(0)
  }
}
