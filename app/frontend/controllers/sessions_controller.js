import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "pushSubscriptionEndpoint" ]

  async logout(event) {
    await this.#unsubscribeFromWebPush()
    this.element.requestSubmit()
  }

  async #unsubscribeFromWebPush() {
    if ("serviceWorker" in navigator) {
      try {
        // Get registration without specifying a scope
        const registration = await navigator.serviceWorker.getRegistration()

        if (registration) {
          const subscription = await registration.pushManager.getSubscription()

          if (subscription) {
            this.pushSubscriptionEndpointTarget.value = subscription.endpoint
            await subscription.unsubscribe()
          }
        }
      } catch (error) {
        console.error("Error unsubscribing from push notifications:", error)
        // Continue with form submission even if unsubscription fails
      }
    }
  }
}
