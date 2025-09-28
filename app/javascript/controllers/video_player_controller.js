import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["thumbnail", "player"]
  static values = { 
    embedUrl: String,
    vimeoId: String
  }

  connect() {
    // Make sure we have the required values
    if (!this.embedUrlValue) {
      console.error("VideoPlayer: No embed URL provided")
      return
    }
  }

  play(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    // Hide the thumbnail
    if (this.hasThumbnailTarget) {
      this.thumbnailTarget.style.display = "none"
    }
    
    // Show the player and create iframe
    if (this.hasPlayerTarget) {
      this.playerTarget.style.display = "block"
      
      // Clear existing content and create new iframe
      this.playerTarget.innerHTML = ""
      
      const iframe = document.createElement("iframe")
      iframe.src = this.embedUrlValue
      iframe.allow = "autoplay; fullscreen; picture-in-picture; clipboard-write"
      iframe.allowFullscreen = true
      iframe.referrerPolicy = "strict-origin-when-cross-origin"
      iframe.style.position = "absolute"
      iframe.style.inset = "0"
      iframe.style.width = "100%"
      iframe.style.height = "100%"
      iframe.style.border = "0"
      iframe.style.borderRadius = "inherit"
      
      this.playerTarget.appendChild(iframe)
    } else {
      console.error("VideoPlayer: No player target found")
    }
  }

  // Method to reset the player
  reset() {
    if (this.hasThumbnailTarget) {
      this.thumbnailTarget.style.display = "block"
    }
    
    if (this.hasPlayerTarget) {
      this.playerTarget.style.display = "none"
      this.playerTarget.innerHTML = ""
    }
  }
}
