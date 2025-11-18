import { Controller } from "@hotwired/stimulus"
import { nextEventLoopTick } from "helpers/timing_helpers"
import ClientMessage from "models/client_message"
import MessageFormatter, { ThreadStyle } from "models/message_formatter"
import MessagePaginator from "models/message_paginator"
import ScrollManager from "models/scroll_manager"
import ScrollTracker from "models/scroll_tracker"

export default class extends Controller {
  static targets = ["latest", "message", "body", "messages", "template"]
  static classes = [
    "firstOfDay",
    "firstUnread",
    "formatted",
    "me",
    "mentioned",
    "threaded",
    "loadingUp",
    "loadingDown",
  ]
  static values = { pageUrl: String, conversationRoom: Boolean }

  #clientMessage
  #paginator
  #formatter
  #scrollManager
  #scrollTracker

  // Lifecycle

  initialize() {
    this.#formatter = new MessageFormatter(Current.user.id, {
      firstOfDay: this.firstOfDayClass,
      formatted: this.formattedClass,
      me: this.meClass,
      mentioned: this.mentionedClass,
      threaded: this.threadedClass,
    })
  }

  connect() {
    this.#clientMessage = new ClientMessage(this.templateTarget)
    this.#paginator = new MessagePaginator(
      this.messagesTarget,
      this.pageUrlValue,
      this.#formatter,
      this.#allContentViewed.bind(this),
      {
        loadingUp: this.loadingUpClass,
        loadingDown: this.loadingDownClass,
      },
    )
    this.#scrollManager = new ScrollManager(this.messagesTarget)
    this.#scrollTracker = new ScrollTracker(this.messagesTarget, {
      lastChildHidden: this.#showReturnToLatestButton.bind(this),
    })

    if (this.#hasSearchResult) {
      this.#highlightSearchResult()
    } else if (this.#hasUnreadSeparator) {
      this.#scrollToUnreadSeparator()
    } else if (this.conversationRoomValue) {
      this.messagesTarget.scrollTop = 0
    } else {
      this.#scrollManager.autoscroll(true)
    }

    if (this.#scrollTracker.scrolledFarFromLatest) {
      this.#showReturnToLatestButton()
    }

    this.#paginator.monitor()
    this.#scrollTracker.connect()
  }

  disconnect() {
    this.#paginator.disconnect()
    this.#scrollTracker.disconnect()
  }

  messageTargetConnected(target) {
    this.#formatMessage(target)
  }

  bodyTargetConnected(target) {
    this.#formatter.formatBody(target)
  }

  // Actions

  async beforeStreamRender(event) {
    const target = event.detail.newStream.getAttribute("target")
    const action = event.detail.newStream.getAttribute("action")

    const render = event.detail.render

    if (action === "remove") {
      const removedMessage = this.messageTargets.find((el) => el.id === target)
      if (removedMessage) {
        const followingMessage = removedMessage.nextElementSibling
        if (followingMessage) {
          event.detail.render = async (streamElement) => {
            await render(streamElement)
            await nextEventLoopTick()
            // Re-format the message following the deleted one, in case we need to re-draw message separators or re-thread messages
            this.#formatMessage(followingMessage)
          }
        }
      }
    }

    if (target === this.messagesTarget.id) {
      const upToDate = this.#paginator.upToDate

      if (upToDate) {
        event.detail.render = async (streamElement) => {
          const didScroll = await this.#scrollManager.autoscroll(
            false,
            async () => {
              await render(streamElement)
              await nextEventLoopTick()

              this.#positionLastMessage()
              this.#playSoundForLastMessage()
              this.#paginator.trimExcessMessages(true)
            },
          )
          if (!didScroll) {
            this.#showReturnToLatestButton(true)
          }
        }
      } else {
        if (action === "append") event.preventDefault()
        this.#showReturnToLatestButton(true)
      }
    }
  }

  async returnToLatest() {
    if (!this.#paginator.upToDate) {
      this.latestTarget.classList.add("busy")
    }
    await this.#ensureUpToDate()
    this.#scrollManager.autoscroll(true)
    this.#hideReturnToLatestButton()
  }

  async editMyLastMessage() {
    const editorEmpty = document
      .querySelector("#composer trix-editor")
      .matches(":empty")

    if (editorEmpty && this.#paginator.upToDate) {
      this.#myLastMessage?.querySelector(".message__edit-btn")?.click()
    }
  }

  #hideReturnToLatestButton() {
    this.latestTarget.hidden = true
    this.latestTarget.classList.remove("pulse", "busy")
  }

  #showReturnToLatestButton(pulse = false) {
    this.latestTarget.classList.toggle("pulse", pulse)
    this.latestTarget.hidden = false
  }

  // Outlet actions

  async insertPendingMessage(clientMessageId, node) {
    await this.#ensureUpToDate()

    return this.#scrollManager.autoscroll(true, async () => {
      const message = this.#clientMessage.render(clientMessageId, node)
      this.messagesTarget.insertAdjacentHTML("beforeend", message)
    })
  }

  updatePendingMessage(clientMessageId, body) {
    this.#clientMessage.update(clientMessageId, body)
  }

  failPendingMessage(clientMessageId) {
    this.#clientMessage.failed(clientMessageId)
  }

  // Callbacks

  #allContentViewed() {
    this.#hideReturnToLatestButton()
  }

  // Internal

  async #ensureUpToDate() {
    if (!this.#paginator.upToDate) {
      await this.#paginator.resetToLastPage()
    }
  }

  #highlightSearchResult() {
    const highlightId = location.pathname.split("@").pop()
    const highlightMessage = this.messagesTarget.querySelector(
      `.message[data-message-id="${highlightId}"]`,
    )
    if (highlightMessage) {
      highlightMessage.classList.add("search-highlight")
      highlightMessage.scrollIntoView({ behavior: "instant", block: "center" })
    }

    const reply = new URLSearchParams(window.location.search).get("reply")
    if (highlightMessage && reply === "true") {
      highlightMessage
        .querySelector(`button[data-action="reply#reply"]`)
        ?.click()
      this.#removeReplyParam()
    }

    this.#paginator.upToDate = false
  }

  #scrollToUnreadSeparator() {
    this.#unreadSeparator.scrollIntoView({ behavior: "instant" })
    const targetTopOffset = window.innerHeight * 0.1
    const topOffset = this.#unreadSeparator.getBoundingClientRect().top
    if (topOffset < targetTopOffset) {
      this.messagesTarget.scrollBy(0, topOffset - targetTopOffset)
    }

    this.#paginator.upToDate = false
  }

  #removeReplyParam() {
    try {
      const url = new URL(window.location)
      url.searchParams.delete("reply")
      window.history.replaceState({}, document.title, url.toString())
    } catch {}
  }

  get #hasSearchResult() {
    return location.pathname.includes("@")
  }

  get #hasUnreadSeparator() {
    return !!this.#unreadSeparator
  }

  get #unreadSeparator() {
    return this.messagesTarget.querySelector(`.${this.firstUnreadClass}`)
  }

  get #lastMessage() {
    return this.messagesTarget.children[this.messagesTarget.children.length - 1]
  }

  get #myLastMessage() {
    const myMessages = this.messagesTarget.querySelectorAll(`.${this.meClass}`)
    return myMessages[myMessages.length - 1]
  }

  #positionLastMessage() {
    const followingMessage = this.#followingMessage(this.#lastMessage)

    if (followingMessage) {
      followingMessage.before(this.#lastMessage)
      this.#formatMessage(followingMessage)
    }
  }

  #playSoundForLastMessage() {
    const soundTarget = this.#lastMessage.querySelector(".sound")

    if (soundTarget) {
      this.dispatch("play", { target: soundTarget })
    }
  }

  #followingMessage(message) {
    const messageSortValue = this.#sortValue(message)
    let followingMessage = null
    let previousMessage = message.previousElementSibling

    while (messageSortValue < this.#sortValue(previousMessage)) {
      followingMessage = previousMessage
      previousMessage = previousMessage.previousElementSibling
    }

    return followingMessage
  }

  #sortValue(node) {
    return (node && parseInt(node.dataset.sortValue)) || 0
  }

  #formatMessage(message) {
    this.#formatter.format(message, ThreadStyle.thread)

    // Also re-format all threaded messages above, to make sure they still need to be threaded
    // (appending current message might have removed the pending message above it and cause inconsistencies in message threads)
    let current = message.previousElementSibling
    while (
      current &&
      current.classList.contains(this.formattedClass) &&
      current.classList.contains(this.threadedClass)
    ) {
      this.#formatter.format(current, ThreadStyle.thread)
      current = current.previousElementSibling
    }
  }
}
