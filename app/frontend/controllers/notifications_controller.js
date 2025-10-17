import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { pageIsTurboPreview } from "helpers/turbo_helpers"
import { onNextEventLoopTick } from "helpers/timing_helpers"
import { getCookie, setCookie } from "lib/cookie"

export default class extends Controller {
  static values = { subscriptionsUrl: String }
  static targets = [ "notAllowedNotice", "bell", "details" ]
  static classes = [ "attention" ]

  async connect() {
    if (!pageIsTurboPreview()) {
      if (window.notificationsPreviouslyReady) {
        onNextEventLoopTick(() => this.dispatch("ready"))
        this.#hideNotificationContainer()
      } else {
        const firstTimeReady = await this.isEnabled()

        if (firstTimeReady) {
          onNextEventLoopTick(() => this.dispatch("ready"))
          window.notificationsPreviouslyReady = true
          this.#hideNotificationContainer()
        } else {
          this.#showNotificationBell()
        }
      }
    }
  }

  async attemptToSubscribe() {
    if (window.location.protocol === 'http:') {
      // For local development, just show the dialog without attempting to subscribe
      this.#revealNotAllowedNotice()
      return
    }

    if (this.#allowed) {
      const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker()

      switch(Notification.permission) {
        case "denied":  { this.#revealNotAllowedNotice(); break }
        case "granted": { this.#subscribe(registration); break }
        case "default": { this.#requestPermissionAndSubscribe(registration) }
      }
    } else {
      this.#revealNotAllowedNotice()
    }

    this.#endFirstRun()
  }

  async isEnabled() {
    if (this.#allowed) {
      const registration = await this.#serviceWorkerRegistration
      const existingSubscription = await registration?.pushManager?.getSubscription()

      return Notification.permission == "granted" && registration && existingSubscription
    } else {
      return false
    }
  }

  get #allowed() {
    return navigator.serviceWorker && window.Notification
  }

  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration()
  }

  #registerServiceWorker() {
    return navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
  }

  #revealNotAllowedNotice() {
    this.notAllowedNoticeTarget.showModal()
    this.#openSingleOption()
  }

  #openSingleOption() {
    const visibleElements = this.detailsTargets.filter(item => !this.#isHidden(item))

    if (visibleElements.length === 1) {
      this.detailsTargets.forEach(item => item.toggleAttribute("open", item === visibleElements[0]))
    }
  }

  #showNotificationBell() {
    // Show the bell and the alert icon
    this.bellTarget.querySelectorAll("img").forEach(img => img.toggleAttribute("hidden"))
    
    // Add the pulsing effect if it's the first run
    if (!this.#hasSeenFirstRun) {
      this.bellTarget.classList.add(this.attentionClass)
    }
  }

  #hideNotificationContainer() {
    // Hide the entire container when notifications are enabled
    const container = document.getElementById('notification_bell_container')
    if (container) {
      container.style.display = 'none'
    }
  }

  #endFirstRun() {
    this.bellTarget.classList.remove(this.attentionClass)
    this.#markFirstRunSeen()
  }

  async #subscribe(registration) {
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        this.#syncPushSubscription(subscription)
        this.dispatch("ready")
        this.#hideNotificationContainer()
      })
  }

  async #syncPushSubscription(subscription) {
    const response = await post(this.subscriptionsUrlValue, { body: this.#extractJsonPayloadAsString(subscription), responseKind: "turbo-stream" })
    if (!response.ok) subscription.unsubscribe()
  }

  async #requestPermissionAndSubscribe(registration) {
    const permission = await Notification.requestPermission()
    if (permission === "granted") this.#subscribe(registration)
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="vapid-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
  }

  get #hasSeenFirstRun() {
    if (this.#isPWA) {
      return getCookie("notifications-pwa-first-run-seen")
    } else {
      return getCookie("notifications-first-run-seen")
    }
  }

  #markFirstRunSeen = (event) => {
    if (this.#isPWA) {
      setCookie("notifications-pwa-first-run-seen", true)
    } else {
      setCookie("notifications-first-run-seen", true)
    }
  }

  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()
    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } })
  }

  // VAPID public key comes encoded as base64 but service worker registration needs it as a Uint8Array
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }

  #isHidden(item) {
    return (item.offsetParent === null)
  }

  get #isPWA() {
    return window.matchMedia("(display-mode: standalone)").matches
  }
}
