import { Controller } from "@hotwired/stimulus"

// This controller manually adds the `.busy` class to the button after confirmation,
// instead of relying on `[aria-busy]` or `:disabled` styling.
//
// Reason: Turbo enables the form/button immediately before replacing the DOM,
// which causes any CSS tied to `:disabled` (like hiding the icon and showing a spinner)
// to flicker for a split second before the replacement lands.
//
// By applying `.busy` manually and controlling visibility with that class,
// we ensure the spinner stays visible and the icon does not flash back in during the transition.
export default class extends Controller {
    connect() {
        const form = this.element.closest("form");
        
        this.submitHandler = (event) => {
            if (event.target === form) {
                this.element.classList.add("busy")
            }
        }
        document.addEventListener("turbo:submit-start", this.submitHandler.bind(this))
    }

    disconnect() {
        document.removeEventListener("turbo:submit-start", this.submitHandler.bind(this))
    }
}