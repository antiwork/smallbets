// Keep the permanent #sidebar in sync with the current page's :sidebar content
// Works with Turbo navigation and direct loads without interfering with Inertia pages

function getSidebarElements() {
  const sidebar = document.getElementById("sidebar")
  const slot = document.getElementById("sidebar-slot")
  return { sidebar, slot }
}

function isInertiaPage() {
  // Inertia mounts into #app with data-page. If present, Library handles DOM itself.
  const app = document.getElementById("app")
  return !!(app && app.dataset.page)
}

function isSidebarAllowedOnPage() {
  const body = document.body
  return (
    body.classList.contains("sidebar") ||
    body.classList.contains("library-collapsed")
  )
}

function syncSidebarFromSlot() {
  const { sidebar, slot } = getSidebarElements()
  if (!sidebar || !slot) return

  // If this page doesn't allow a sidebar, ensure it's cleared/closed
  if (!isSidebarAllowedOnPage()) {
    sidebar.innerHTML = ""
    sidebar.classList.remove("open")
    return
  }

  // Do not interfere with Inertia pages; Library manages the sidebar itself
  if (isInertiaPage()) return

  // If we already have the standard sidebar turbo-frame mounted, keep it
  // This preserves Turbo-permanent behavior and avoids re-rendering
  if (sidebar.querySelector("#user_sidebar")) return

  // Populate from slot only when empty/missing
  const html = slot.innerHTML.trim()
  if (html.length > 0) sidebar.innerHTML = html
}

// Initial sync on DOM ready or when Turbo loads a new page
function install() {
  // Direct loads
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", syncSidebarFromSlot)
  } else {
    syncSidebarFromSlot()
  }

  // Turbo navigations
  document.addEventListener("turbo:render", syncSidebarFromSlot)
}

install()
