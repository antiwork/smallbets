import { get } from "@rails/request.js"
import {
  insertHTMLFragment,
  parseHTMLFragment,
  keepScroll,
  trimChildren,
} from "helpers/dom_helpers"
import { ThreadStyle } from "models/message_formatter"
import ScrollTracker from "models/scroll_tracker"

const MAX_MESSAGES = 300
const MAX_MESSAGES_LEEWAY = 20

export default class MessagePaginator {
  #container
  #url
  #messageFormatter
  #allContentViewedCallback
  #scrollTracker
  #classes
  #upToDate = true

  constructor(container, url, messageFormatter, allContentViewedCallback, classes) {
    this.#container = container
    this.#url = url
    this.#messageFormatter = messageFormatter
    this.#allContentViewedCallback = allContentViewedCallback
    this.#scrollTracker = new ScrollTracker(container, { lastChildRevealed: this.#messageBecameVisible.bind(this) })
    this.#classes = classes
  }


  // API

  monitor() {
    this.#scrollTracker.connect()
  }

  disconnect() {
    this.#scrollTracker.disconnect()
  }

  get upToDate() {
    return this.#upToDate
  }

  set upToDate(value) {
    this.#upToDate = value
  }

  async resetToLastPage() {
    this.upToDate = true
    await this.#showLastPage()
  }

  async trimExcessMessages(top) {
    const overage = this.#container.children.length - MAX_MESSAGES
    if (overage > MAX_MESSAGES_LEEWAY) {
      trimChildren(overage, this.#container, top)
      if (!top) {
        this.upToDate = false
      }
    }
  }

  // Internal

  #messageBecameVisible(element) {
    const messageId = element.dataset.messageId
    const firstMessage = element === this.#container.firstElementChild
    const lastMessage = element === this.#container.lastElementChild

    if (messageId) {
      if (firstMessage) {
        element.classList.add(this.#classes.loadingUp)
        this.#addPage({ before: messageId }, true)
      }
      if (lastMessage && !this.upToDate) {
        element.classList.add(this.#classes.loadingDown)
        this.#addPage({ after: messageId }, false)
      }
      if (lastMessage && this.upToDate) {
        this.#allContentViewedCallback?.()
      }
    }
  }

  async #showLastPage() {
    const resp = await this.#fetchPage()
    if (resp.statusCode === 200) {
      const page = await this.#formatPage(resp)
      this.#container.replaceChildren(page)
    }
  }

  async #addPage(params, top) {
    const resp = await this.#fetchPage(params)

    if (resp.statusCode === 204 && !top) {
      this.upToDate = true
      this.#allContentViewedCallback?.()
    }

    if (resp.statusCode === 200) {
      const page = await this.#formatPage(resp)
      const lastNewElement = page.lastElementChild

      keepScroll(this.#container, top, () => {
        this.#hideLoadingIndicators()
        insertHTMLFragment(page, this.#container, top)

        // Ensure formatting is correct over page boundaries
        if (top && lastNewElement?.nextElementSibling) {
          this.#messageFormatter.format(lastNewElement.nextElementSibling, ThreadStyle.thread)
        }
      })

      this.trimExcessMessages(!top)
    }

    this.#hideLoadingIndicators()
  }

  async #fetchPage(params) {
    const url = new URL(this.#url)
    for (const param in params) {
      url.searchParams.set(param, params[param])
    }

    return await get(url)
  }

  async #formatPage(response) {
    const text = await response.html
    const fragment = parseHTMLFragment(text)

    for (const message of fragment.querySelectorAll(".message")) {
      this.#messageFormatter.format(message, ThreadStyle.thread)
    }

    return fragment
  }
  
  #hideLoadingIndicators() {
    this.#container.querySelectorAll(`.${this.#classes.loadingUp}`).forEach(el => {
      el.classList.remove(this.#classes.loadingUp);
    });

    this.#container.querySelectorAll(`.${this.#classes.loadingDown}`).forEach(el => {
      el.classList.remove(this.#classes.loadingDown);
    });
  }
}
