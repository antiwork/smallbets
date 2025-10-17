import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "container"]

  filter() {
    
    const query = this.inputTarget.value.toLowerCase()
    
    // Get all room elements within the container
    const rooms = this.containerTarget.querySelectorAll("[data-search-text]")

    rooms.forEach(room => {
      const searchText = room.dataset.searchText.toLowerCase()
      const shouldShow = searchText.includes(query)
      
      room.style.display = shouldShow ? '' : 'none'
    })
  }
}