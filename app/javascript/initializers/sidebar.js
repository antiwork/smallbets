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
  if (isInertiaPage()) return

  const { sidebar, slot } = getSidebarElements()
  if (!sidebar || !slot) return

  const html = slot.innerHTML.trim()

  // No sidebar on this page: clear and close
  if (html.length === 0 || !isSidebarAllowedOnPage()) {
    sidebar.innerHTML = ""
    sidebar.classList.remove("open")
    return
  }

  // Replace content only if different to avoid unnecessary reflows
  if (sidebar.innerHTML !== html) sidebar.innerHTML = html
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
