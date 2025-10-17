import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import Selection from "lib/autocomplete/selection"

export default class extends BaseAutocompleteHandler {
  #selection

  constructor(element, select, url) {
    super(element, url)
    this.#selection = new Selection(select)
  }

  disconnect() {
    this.#selection.disconnect()
  }


  insertAutocompletable(autocompletable) {
    this.#selection.add(autocompletable.value, autocompletable.name, { avatarUrl: autocompletable.avatar_url })
    this.element.value = ""
  }

  get pattern() {
    return new RegExp(`^(.*?)$`)
  }

  remove(value) {
    this.#selection.remove(value)
  }

  removeLastSelection() {
    this.#selection.removeLast()
  }

  search(term) {
    super.updateWithContentAndPosition(term, 0)
  }

  setAutocompletables(autocompletables) {
    super.setAutocompletables(this.#filterSelectedAutocompletables(autocompletables))
  }

  #filterSelectedAutocompletables(autocompletables) {
    const selectedValues = this.#selection.values.concat(Current.user.id)
    return autocompletables.filter(autocompletable => !selectedValues.includes(autocompletable.value))
  }
}
