import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "room" ]

  connect() {
    this.toggleRooms()
  }

  roomTargetConnected(element) {
    this.#toggleRoom(element)
    this.#toggleSidebarSection()
  }

  roomTargetDisconnected(element) {
    this.#toggleSidebarSection()
  }

  toggleRooms() {
    this.roomTargets.forEach((room) => {
      this.#toggleRoom(room) 
    })

    this.#toggleSidebarSection()
  }
  
  #toggleRoom(room) {
    const involvement = room.dataset.involvement
    const isVisible = (involvement === "everything") 
    
    if (isVisible) {
      room.removeAttribute("hidden")
      this.#showParentRooms(room)
    } else {
      room.setAttribute("hidden", true)
    }
  }

  #toggleSidebarSection() {
    const hasVisibleRoom = this.roomTargets.some(room => !room.hasAttribute("hidden"))

    if (hasVisibleRoom) {
      this.element.removeAttribute("hidden")
    } else {
      this.element.setAttribute("hidden", true)
    }
  }

  #showParentRooms(room) {
    let parentRoom = room.parentElement.closest("[data-sidebar-starred-rooms-target='room']")
    
    while (parentRoom) {
      parentRoom.removeAttribute("hidden")
      parentRoom = parentRoom.parentElement.closest("[data-sidebar-starred-rooms-target=room]")
    }
  }
}
