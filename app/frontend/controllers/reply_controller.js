import { Controller } from "@hotwired/stimulus"

const unfurled_attachment_selector = ".og-embed"

export default class extends Controller {
  static targets = [ "body", "link", "author" ]
  static outlets = [ "composer" ]

  connect() {
    this.#formatLinkTargets()
  }

  reply() {
    const content = `<blockquote>${this.#bodyContent}</blockquote><cite>${this.authorTarget.innerHTML} ${this.#linkToOriginal}</cite><br>`
    this.composerOutlet.replaceMessageContent(content)
  }

  #formatLinkTargets() {
    this.bodyTarget.querySelectorAll("a").forEach(link => {
      if (this.#isInternalLink(link)) {
        link.target = "_top"
      } else {
        link.target = "_blank"
        link.rel = "noopener noreferrer"
      }
    })
  }
  
  #isInternalLink(link) {
    const currentHostname = window.location.hostname
    const linkHostname = new URL(link.href, window.location.href).hostname
    
    if (linkHostname === currentHostname) return true
    if (this.#getRootDomain(linkHostname) === this.#getRootDomain(currentHostname)) return true

    return false
  }
  
  #getRootDomain(hostname) {
    return hostname.includes('.') ? hostname.split('.').slice(-2).join('.') : hostname
  }

  get #bodyContent() {
    const body = this.bodyTarget.querySelector(".trix-content").cloneNode(true)
    return this.#stripMentionAttachments(this.#stripUnfurledAttachments(body)).innerHTML
  }

  #stripMentionAttachments(node) {
    node.querySelectorAll(".mention").forEach(mention => {
      mention.querySelector("details")?.remove();
      mention.outerHTML = mention.textContent.trim()
    })
    return node
  }

  #stripUnfurledAttachments(node) {
    const firstUnfurledLink = node.querySelector(`${unfurled_attachment_selector} a`)?.href
    node.querySelectorAll(unfurled_attachment_selector).forEach(embed => embed.remove())

    // Use unfurled link as the content when the node has no additional text
    if (firstUnfurledLink && !node.textContent.trim()) node.textContent = firstUnfurledLink

    return node
  }

  get #linkToOriginal() {
    return `<a href="${this.linkTarget.getAttribute('href')}">#</a>`
  }
}
