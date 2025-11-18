import { memoize } from "lib/autocomplete/utils"

export default class Selection {
  #elements = []
  #element
  #observer

  constructor(element) {
    this.#element = element
    this.#observeMutations()
    this.#render()
  }

  disconnect() {
    this.#observer.disconnect()
    this.#render()
  }

  add(value, label, options = {}) {
    this.#element.append(this.#findOption(value) || this.#createOption(value, label, options))
  }

  remove(value) {
    this.#findOption(value)?.remove()
  }

  removeLast() {
    this.#lastOption?.remove()
  }

  get values() {
    return this.#options.map(option => parseInt(option.value))
  }

  #createOption(value, label, { avatarUrl }) {
    const option = new Option(label, value, true, true)
    option.dataset.avatarUrl = avatarUrl
    return option
  }

  #findOption(value) {
    return this.#options.find(option => option.value == value)
  }

  get #lastOption() {
    return this.#options.slice(-1)[0]
  }

  #observeMutations() {
    this.#observer = new MutationObserver(this.#optionsChanged)
    this.#observer.observe(this.#element, { childList: true })
  }

  #optionsChanged = () => {
    this.#render()
  }

  get #options() {
    return Array.from(this.#element.options)
  }

  #render() {
    for (const element of this.#elements) element.remove()
    this.#elements = this.#element.isConnected ? this.#options.map(this.#renderElementForOption) : []
   }

  #renderElementForOption = (option) => {
    const { value, label } = option
    const content = this.#template.content.cloneNode(true)
    content.querySelectorAll("[data-value]").forEach(element => element.dataset.value = value)
    content.querySelector("[data-content=label]").textContent = label
    content.querySelector("[data-content=label]").title = value
    content.querySelector("[data-content=screenReaderLabel]").textContent = label
    content.querySelector("[data-content=avatar]").src = option.dataset.avatarUrl
    return this.#template.insertAdjacentElement("beforebegin", content.firstElementChild)
  }

  get #template() {
    const id = this.#element.getAttribute("data-template-id")
    return memoize(this, "template", document.getElementById(id))
  }
}
