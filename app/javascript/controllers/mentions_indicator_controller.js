import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon" ]

  connect() {
    this.updateIndicator()

    // Use MutationObserver to watch for any class changes in the sidebar
    this.observer = new MutationObserver(() => {
      this.updateIndicator()
    })

    // Observe the sidebar container for changes to class attributes
    const sidebarContainer = this.element.querySelector('.sidebar__container')
    if (sidebarContainer) {
      this.observer.observe(sidebarContainer, {
        attributes: true,
        attributeFilter: ['class'],
        subtree: true,
        childList: true
      })
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  update() {
    this.updateIndicator()
  }

  updateIndicator() {
    // Check if there are any rooms with the badge class (unread mentions) or unread direct messages
    const hasUnreadMentions = this.element.querySelectorAll('.room.badge').length > 0
    const hasUnreadDirects = this.element.querySelectorAll('.direct.unread').length > 0

    if (hasUnreadMentions || hasUnreadDirects) {
      this.iconTarget.classList.add('has-unread-mentions')
    } else {
      this.iconTarget.classList.remove('has-unread-mentions')
    }
  }
}
