import { Controller } from "@hotwired/stimulus"

// Re-renders the page periodically (Turbo morph) so day counts roll over at
// midnight even when no poll changed anything.
export default class extends Controller {
  static values = { interval: { type: Number, default: 15 * 60 * 1000 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (document.visibilityState !== "visible") return
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
