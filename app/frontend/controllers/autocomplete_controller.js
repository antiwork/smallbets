import { Controller } from "@hotwired/stimulus"
import AutocompleteHandler from "lib/autocomplete/autocomplete_handler"
import { debounce } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "select", "input" ]
  static values = { url: String }

  #handler

  initialize() {
    this.search = debounce(this.search.bind(this), 300)
  }

  connect() {
    this.#installHandler()
    this.inputTarget.focus()
  }

  disconnect() {
    this.#uninstallHandler()
  }

  search(event) {
    this.#handler.search(event.target.value)
  }

  didPressKey(event) {
    if (event.key == "Backspace" && this.inputTarget.value == "") {
      this.#handler.removeLastSelection()
    }
  }

  remove(event) {
    this.#handler.remove(event.target.closest("button").dataset.value)
    this.inputTarget.focus()
  }

  #installHandler() {
    this.#uninstallHandler()
    this.#handler = new AutocompleteHandler(this.inputTarget, this.selectTarget, this.urlValue)
  }

  #uninstallHandler() {
    this.#handler?.disconnect()
    this.#handler?.destroy()
  }
}
