import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "time", "date", "datetime", "longdatetime", "relative" ]

  initialize() {
    this.timeFormatter = new Intl.DateTimeFormat(undefined, { timeStyle: "short" })
    this.dateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: "long" })
    this.dateTimeFormatter = new Intl.DateTimeFormat(undefined, { timeStyle: "short", dateStyle: "short" })
    this.longDateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: "long" })
  }

  connect() {
    this.relativeInterval = setInterval(() => {
      this.updateRelativeTimes();
    }, 30000);
  }

  disconnect() {
    clearInterval(this.relativeInterval);
  }

  timeTargetConnected(target) {
    this.#formatTime(this.timeFormatter, target)
  }

  dateTargetConnected(target) {
    this.#formatTime(this.dateFormatter, target)
  }

  datetimeTargetConnected(target) {
    this.#formatTime(this.dateTimeFormatter, target)
  }

  longdatetimeTargetConnected(target) {
    const dt = new Date(target.getAttribute("datetime"))
    const datePart = this.longDateFormatter.format(dt)
    const timePart = this.timeFormatter.format(dt)
    target.textContent = `${datePart} at ${timePart}`
    target.title = this.dateTimeFormatter.format(dt)
  }

  relativeTargetConnected(target) {
    this.formatRelativeTime(target);
  }

  updateRelativeTimes() {
    this.relativeTargets.forEach((target) => this.formatRelativeTime(target));
  }

  #formatTime(formatter, target) {
    const dt = new Date(target.getAttribute("datetime"))
    target.textContent = formatter.format(dt)
    target.title = this.dateTimeFormatter.format(dt)
  }

  formatRelativeTime(target) {
    const dt = new Date(target.closest("[data-updated-at]").dataset.updatedAt);
    const diffSeconds = (Date.now() - dt.getTime()) / 1000;
    let text;

    if (diffSeconds < 60) {
      text = "just now";
    } else if (diffSeconds < 3600) {
      text = `${Math.floor(diffSeconds / 60)}m ago`;
    } else if (diffSeconds < 86400) {
      text = `${Math.floor(diffSeconds / 3600)}h ago`;
    } else {
      text = `${Math.floor(diffSeconds / 86400)}d ago`;
    }

    target.textContent = text;
    target.title = this.dateTimeFormatter.format(dt);
  }
}
