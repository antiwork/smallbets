import { createInertiaApp } from "@inertiajs/react"
import { createElement, ReactNode } from "react"
import { createRoot } from "react-dom/client"
import type { Root } from "react-dom/client"
import { toast } from "sonner"

import { Toaster } from "../components/ui/sonner"

// Temporary type definition, until @inertiajs/react provides one
type ResolvedComponent = {
  default: ReactNode
  layout?: (page: ReactNode) => ReactNode
}

type ToastVariant = "success" | "error" | "info" | "warning" | "message"

interface ToastEventDetail {
  message: string
  type?: ToastVariant
}

declare global {
  interface Window {
    __sbToastListenerAttached?: boolean
    __sb_page_boot_ts?: number
  }
}

const TOAST_EVENT = "toast:show"

let toastRoot: Root | null = null
let toastContainer: HTMLElement | null = null

function bootInertiaApp() {
  const mount = document.getElementById("app") as HTMLElement | null

  if (!mount) {
    return
  }

  if (mount.dataset.inertiaMounted === "true") {
    return
  }

  const pagePayload = mount.dataset.page

  if (!pagePayload) {
    return
  }

  const initialPage = JSON.parse(pagePayload)

  // Mark page boot for early-mousemove suppression during initial render
  window.__sb_page_boot_ts = performance.now?.() ?? Date.now()

  createInertiaApp({
    id: mount.id,
    page: initialPage,
    resolve: (name) => {
      const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.tsx", {
        eager: true,
      })
      const page = pages[`../pages/${name}.tsx`]
      if (!page) {
        console.error(`Missing Inertia page component: '${name}.tsx'`)
      }

      return page
    },
    setup({ el, App, props }) {
      if (!el) {
        console.error(
          "Missing root element.\n\n" +
            "If you see this error, it probably means you load Inertia.js on non-Inertia pages.\n" +
            'Consider moving <%= vite_typescript_tag "inertia" %> to the Inertia-specific layout instead.',
        )
        return
      }

      const root = createRoot(el)
      root.render(createElement(App, props))
      mount.dataset.inertiaMounted = "true"

      const handleBeforeCache = () => {
        root.unmount()
        delete mount.dataset.inertiaMounted
        document.removeEventListener("turbo:before-cache", handleBeforeCache)
      }

      document.addEventListener("turbo:before-cache", handleBeforeCache)
    },
  }).catch((error) => {
    console.error("[Inertia] Failed to bootstrap page", error)
  })
}

function mountToaster() {
  const container = document.getElementById(
    "toast-portal",
  ) as HTMLElement | null

  if (!container) {
    return
  }

  toastContainer = container

  if (container.dataset.reactMounted === "true" && toastRoot) {
    return
  }

  toastRoot = createRoot(container)
  toastRoot.render(createElement(Toaster))
  container.dataset.reactMounted = "true"
}

function teardownToaster() {
  if (toastRoot) {
    toastRoot.unmount()
    toastRoot = null
  }

  if (toastContainer) {
    delete toastContainer.dataset.reactMounted
    toastContainer = null
  }
}

function showToast(message: string, type: ToastVariant = "success") {
  if (!message) return

  mountToaster()

  if (type === "message") {
    toast.message(message)
    return
  }

  const variantMap: Partial<
    Record<Exclude<ToastVariant, "message">, (value: string) => void>
  > = {
    success: toast.success,
    error: toast.error,
    info: toast.info,
    warning: toast.warning,
  }

  const variant = variantMap[type]

  if (variant) {
    variant(message)
    return
  }

  toast(message)
}

function handleToastEvent(event: Event) {
  if (!("detail" in event)) return

  const customEvent = event as CustomEvent<ToastEventDetail>
  if (!customEvent.detail?.message) return

  showToast(customEvent.detail.message, customEvent.detail.type)
}

function ensureToastListener() {
  if (window.__sbToastListenerAttached) {
    return
  }

  window.addEventListener(TOAST_EVENT, handleToastEvent)
  window.__sbToastListenerAttached = true
}

function flushFlashMessages() {
  const inertiaRoot = document.getElementById("app") as HTMLElement | null
  const isInertiaPage = Boolean(inertiaRoot?.dataset.page)

  if (isInertiaPage) {
    return
  }

  const flashContainers = document.querySelectorAll<HTMLElement>(
    "[data-flash-container]",
  )

  flashContainers.forEach((container) => {
    const notice = container.dataset.flashNotice
    const alert = container.dataset.flashAlert

    if (notice) {
      showToast(notice, "success")
      delete container.dataset.flashNotice
    }

    if (alert) {
      showToast(alert, "error")
      delete container.dataset.flashAlert
    }
  })
}

function bootToaster() {
  mountToaster()
  ensureToastListener()
  flushFlashMessages()
}

function boot() {
  bootInertiaApp()
  bootToaster()
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot)
} else {
  boot()
}

document.addEventListener("turbo:load", boot)
document.addEventListener("turbo:before-cache", () => {
  teardownToaster()
})
