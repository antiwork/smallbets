import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { target: String }

    load() {
        if (!this.targetValue) return

        const frame = document.getElementById(this.targetValue)
        if (frame) {
            // Trigger the lazy-involvement controller to load
            const lazyController = this.application.getControllerForElementAndIdentifier(frame, "lazy-involvement")
            if (lazyController) {
                lazyController.load()
            }
        }
    }
}
