export default class extends HTMLElement {
  connectedCallback() {
    if (!this.hasAttribute("role")) this.setAttribute("role", "listbox")
  }

  get optionElements() {
    return this.querySelectorAll("suggestion-option")
  }

  get selectedIndex() {
    const selected = this.querySelector("suggestion-option[selected]")
    return selected?.index
  }

  set selectedIndex(value) {
    const optionElements = this.optionElements
    const optionCount = optionElements.length

    if (!optionElements.length) return

    Array.from(optionElements).forEach(option => {
      option.selected = false
    })

    if (value === null || typeof value === "undefined") return

    const index = Math.max(0, Math.min(optionCount - 1, parseInt(value, 10)))
    optionElements[index].selected = true
  }

  get selectedOption() {
    return this.optionElements[this.selectedIndex]
  }

  set selectedOption(option) {
    if (option.selectElement === this) {
      this.selectedIndex = option.index
    }
  }

  get value() {
    return this.selectedOption?.value
  }
}
