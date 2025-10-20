import { createInertiaApp } from "@inertiajs/react"
import { createElement, ReactNode } from "react"
import { createRoot } from "react-dom/client"

// Temporary type definition, until @inertiajs/react provides one
type ResolvedComponent = {
  default: ReactNode
  layout?: (page: ReactNode) => ReactNode
}

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
  ;(window as any).__sb_page_boot_ts = performance.now?.() ?? Date.now()

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

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootInertiaApp)
} else {
  bootInertiaApp()
}

document.addEventListener("turbo:load", bootInertiaApp)
