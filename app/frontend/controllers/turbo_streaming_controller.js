import { Controller } from "@hotwired/stimulus"

// Unsubscribe a container from turbo streaming actions (by removing its id) can address timing jank
// when turbo streaming updates race against a full controller response.
export default class extends Controller {
  static targets = [ "container" ]

  unsubscribe() {
    this.containerTarget.removeAttribute("id")
  }
}
