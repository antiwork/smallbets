import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "loading", "error", "list", "fallback" ]
  static values = {
    downloadsUrl: String,
    downloadPath: String,
    title: String,
    defaultQuality: { type: String, default: "" }
  }

  #cancelHandler = event => this.close(event)

  connect() {
    this.hasLoaded = false
    this.isLoading = false

    if (this.hasDialogTarget) {
      this.dialogTarget.addEventListener("cancel", this.#cancelHandler)
    }
  }

  disconnect() {
    if (this.hasDialogTarget) {
      this.dialogTarget.removeEventListener("cancel", this.#cancelHandler)
    }
  }

  open(event) {
    event?.preventDefault?.()

    if (!this.hasDialogTarget) return

    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
      this.dialogTarget.focus()
    }

    if (!this.hasLoaded && !this.isLoading) {
      this.#loadDownloads()
    }
  }

  close(event) {
    event?.preventDefault?.()

    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  async #loadDownloads() {
    this.isLoading = true
    this.#resetUi()

    try {
      const response = await fetch(this.downloadsUrlValue, { headers: { Accept: "application/json" } })

      if (!response.ok) {
        throw new Error(`Failed to load downloads: ${response.status}`)
      }

      const downloads = await response.json()
      const entries = Array.isArray(downloads) ? downloads.filter(download => this.#isDownloadEntry(download)) : []

      if (entries.length === 0) {
        this.#showFallback()
        return
      }

      this.hasLoaded = true
      this.#renderDownloads(entries)
    } catch (error) {
      console.error("Unable to load video downloads", error)
      this.#showError()
    } finally {
      this.isLoading = false
    }
  }

  #resetUi() {
    this.loadingTarget.hidden = false
    this.errorTarget.hidden = true
    this.listTarget.hidden = true
    this.listTarget.innerHTML = ""
    this.fallbackTarget.hidden = true
  }

  #renderDownloads(downloads) {
    this.loadingTarget.hidden = true
    this.errorTarget.hidden = true
    this.fallbackTarget.hidden = true
    this.listTarget.hidden = false

    downloads.forEach(download => {
      const item = document.createElement("li")
      item.className = "library__download-item"

      const meta = document.createElement("div")
      meta.className = "library__download-meta"

      const title = document.createElement("span")
      title.className = "library__download-quality"
      title.textContent = this.#qualityLabel(download)

      meta.appendChild(title)

      const detailsText = this.#detailsText(download)
      if (detailsText) {
        const details = document.createElement("span")
        details.className = "library__download-details"
        details.textContent = detailsText
        meta.appendChild(details)
      }

      const action = document.createElement("a")
      action.className = "btn library__download-link"
      action.textContent = "Download"
      action.rel = "nofollow noopener"
      action.target = "_blank"

      const href = this.#downloadHref(download)

      if (href) {
        action.href = href
      } else {
        action.removeAttribute("href")
        action.setAttribute("aria-disabled", "true")
      }

      item.append(meta, action)
      this.listTarget.appendChild(item)
    })
  }

  #downloadHref(download) {
    if (download.quality) {
      const url = new URL(this.downloadPathValue, window.location.origin)
      url.searchParams.set("quality", download.quality)
      return url.toString()
    }

    return download.link || null
  }

  #showFallback() {
    this.loadingTarget.hidden = true
    this.errorTarget.hidden = true
    this.listTarget.hidden = true
    this.fallbackTarget.hidden = false
  }

  #showError() {
    this.loadingTarget.hidden = true
    this.errorTarget.hidden = false
    this.listTarget.hidden = true
    this.fallbackTarget.hidden = false
  }

  #qualityLabel(download) {
    if (download.quality) {
      return download.quality.toUpperCase()
    }

    if (download.type) {
      return download.type.toUpperCase()
    }

    return `Download (${this.titleValue})`
  }

  #detailsText(download) {
    const details = []
    const resolution = this.#resolution(download)
    const size = this.#size(download)

    if (resolution) details.push(resolution)
    if (size) details.push(size)

    return details.length > 0 ? details.join(" • ") : ""
  }

  #resolution(download) {
    const { width, height } = download

    if (!width || !height) return ""

    return `${width}×${height}`
  }

  #size(download) {
    if (download.size_short) {
      return download.size_short
    }

    const size = Number(download.size)
    if (!Number.isFinite(size) || size <= 0) return ""

    const units = ["B", "KB", "MB", "GB", "TB"]
    let value = size
    let unitIndex = 0

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024
      unitIndex += 1
    }

    return `${value.toFixed(value >= 10 ? 0 : 1)} ${units[unitIndex]}`
  }

  #isDownloadEntry(download) {
    return download && (download.quality || download.link)
  }
}
