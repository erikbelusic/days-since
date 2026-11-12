import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-and-drop ordering for dashboard cards. Each item carries
// data-sortable-url (PATCH endpoint); the new index is sent as `position`.
export default class extends Controller {
  static values = { handle: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: this.handleValue || undefined,
      ghostClass: "opacity-40",
      onEnd: this.moved.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async moved({ item, oldIndex, newIndex }) {
    if (oldIndex === newIndex) return

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.append("position", newIndex)

    const response = await fetch(item.dataset.sortableUrl, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token, "Accept": "application/json" },
      body
    })
    if (!response.ok) window.location.reload()
  }
}
