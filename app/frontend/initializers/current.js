class Current {
  get user() {
    const currentUserId = this.#extractContentFromMetaTag("current-user-id")

    if (currentUserId) {
      return { 
        id: parseInt(currentUserId), 
        name: this.#extractContentFromMetaTag("current-user-name"),
        role: this.#extractContentFromMetaTag("current-user-role")
      }
    }
  }

  get room() {
    const currentRoomId = this.#extractContentFromMetaTag("current-room-id")

    if (currentRoomId) {
      return { id: parseInt(currentRoomId) }
    }
  }

  #extractContentFromMetaTag(name) {
    return document.head.querySelector(`meta[name="${name}"]`)?.getAttribute("content")
  }
}

window.Current = new Current()
