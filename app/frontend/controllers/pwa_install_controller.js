import { Controller } from "@hotwired/stimulus"
import { getCookie, setCookie } from "lib/cookie"

export default class extends Controller {
  static classes = [ "prompting" ]

  connect() {
    if (this.#canInstall && !this.#isInstalledPWA) {
      window.addEventListener("beforeinstallprompt", this.#preventPrompt)
      window.addEventListener("appinstalled", this.#installed)
    }
  }

  promptInstall = () => {
    this.deferredPrompt.prompt()
  }

  #installed = () => {
    this.element.classList.remove(this.promptingClass)
  }

  #preventPrompt = (event) => {
    event.preventDefault()
    this.deferredPrompt = event;
    this.element.classList.add(this.promptingClass)
  }

  get #canInstall() {
    return "serviceWorker" in navigator
  }

  get #isInstalledPWA() {
    return window.matchMedia("(display-mode: standalone)").matches
  }
}
