import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"
import { ignoringBriefDisconnects } from "helpers/dom_helpers"

export default class extends Controller {
  static targets = [ "room" ]
  static classes = [ "unread", "badge" ]

  #disconnected = true
  #keepCurrentRoomUnread = false

  async connect() {
    this.unreadsChannel ??= await cable.subscribeTo({ channel: "UnreadRoomsChannel" }, {
      connected: this.#channelConnected.bind(this),
      disconnected: this.#channelDisconnected.bind(this),
      received: this.#unread.bind(this)
    })
    this.userUnreadsChannel ??= await cable.subscribeTo({ channel: "UserUnreadRoomsChannel" }, {
      received: this.#unread.bind(this)
    })
    this.notificationsChannel ??= await cable.subscribeTo({ channel: "UnreadNotificationsChannel" }, {
      received: this.#addBadge.bind(this)
    })
    this.roomListChannel ??= await cable.subscribeTo({ channel: "RoomListChannel" }, {
      received: this.#roomUpdated.bind(this)
    })
    this.involvementsChannel ??= await cable.subscribeTo({ channel: "UserInvolvementsChannel" }, {
      received: this.#updateInvolvement.bind(this)
    })
  }

  disconnect() {
    ignoringBriefDisconnects(this.element, () => {
      this.unreadsChannel?.unsubscribe()
      this.unreadsChannel = null

      this.userUnreadsChannel?.unsubscribe()
      this.userUnreadsChannel = null

      this.notificationsChannel?.unsubscribe()
      this.notificationsChannel = null

      this.roomListChannel?.unsubscribe()
      this.roomListChannel = null
    })
  }

  loaded() {
    this.#readCurrentRoom()
  }

  roomTargetConnected(target) {
    if (!this.#keepCurrentRoomUnread && target.dataset.roomId == Current.room?.id) {
      this.#readCurrentRoom()
    }
  }

  read({ detail: { roomId } }) {
    const rooms = this.#findRoomTargets(roomId)

    rooms.forEach(room => {
      if (room.dataset.sortedListPriority) {
        room.dataset.sortedListPriority = "1"
      }
      room.classList.remove(this.unreadClass, this.badgeClass)
      if (Current.room?.id === roomId) {
        this.#keepCurrentRoomUnread = false
      }
      this.dispatch("read", { detail: { targetId: roomId } })
    })
  }

  #channelConnected() {
    if (this.#disconnected) {
      this.#disconnected = false
      this.element.reload()
    }
  }

  #channelDisconnected() {
    this.#disconnected = true
  }

  #unread({ roomId, roomSize, roomUpdatedAt, forceUnread }) {
    const unreadRooms = this.#findRoomTargets(roomId)

    unreadRooms.forEach(unreadRoom => {
      const sortedListTarget = unreadRoom.closest('[data-sorted-list-target]')
      if (!sortedListTarget) return
      
      if (sortedListTarget.dataset.sortedListPriority) {
        sortedListTarget.dataset.sortedListPriority = "0"
      }
      sortedListTarget.dataset.updatedAt = roomUpdatedAt
      sortedListTarget.dataset.size = roomSize
      
      if (forceUnread || Current.room?.id != roomId) {
        unreadRoom.classList.add(this.unreadClass)
      }
      
      if (forceUnread) {
        this.#keepCurrentRoomUnread = true
      }
    })
    
    this.dispatch("unread", { detail: { roomId: roomId } })
  }

  #addBadge({ roomId }) {
    const unreadRooms = this.#findRoomTargets(roomId)

    unreadRooms.forEach(unreadRoom => {
      if (Current.room?.id != roomId) {
        unreadRoom.classList.add(this.badgeClass)
      }
    })

    this.dispatch("addBadge", { detail: { roomId: roomId } })
  }
  
  #roomUpdated({ roomId, sortableName }) {
    const rooms = this.#findRoomTargets(roomId)

    rooms.forEach(room => {
      const sortedListTarget = room.closest('[data-sorted-list-target]')
      if (!sortedListTarget) return
      
      sortedListTarget.dataset.name = sortableName
    })

    this.dispatch("renamed", { detail: { roomId: roomId } })
  }
  
  #updateInvolvement({ roomId, involvement }) {
    const rooms = this.#findRoomTargets(roomId)

    rooms.forEach(room => {
      const list_node = room.closest('[data-type=list_node]')
      if (!list_node) return

      list_node.dataset.involvement = involvement
    })
    
    this.dispatch("involved", { detail: { roomId: roomId } })
  }

  #findRoomTargets(roomId) {
    return this.roomTargets.filter(roomTarget => roomTarget.dataset.roomId == roomId)
  }
  
  #readCurrentRoom() {
    this.read({ detail: { roomId: Current.room?.id } })
  }
}
