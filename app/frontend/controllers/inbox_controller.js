import { Controller } from "@hotwired/stimulus"
import MessageFormatter, { ThreadStyle } from "models/message_formatter"
import MessagePaginator from "models/message_paginator"

export default class extends Controller {
  static targets = [ "messages" ]
  static classes = [ "firstOfDay", "me", "threaded", "mentioned", "formatted", "loadingUp", "loadingDown" ]
  static values = { pageUrl: String }

  #paginator
  #formatter

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
    this.#paginator = new MessagePaginator(this.messagesTarget, this.pageUrlValue, this.#formatter, () => {}, {
      loadingUp: this.loadingUpClass,
      loadingDown: this.loadingDownClass
    })
    
    this.element.scrollTo({ top: this.element.scrollHeight })
    this.#paginator.monitor()
  }

  messageTargetConnected(target) {
    this.#formatter.format(target, ThreadStyle.thread)
  }
}
