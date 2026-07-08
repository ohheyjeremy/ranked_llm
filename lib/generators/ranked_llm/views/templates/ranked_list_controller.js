import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Single-list drag-and-drop reordering: persists position when an item is
// dropped. Always one list — no cross-column "group" concept.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "opacity-40",
      onEnd: event => this.persist(event)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async persist(event) {
    const url = event.item.dataset.moveUrl
    const position = event.newIndex + 1

    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ position })
    })

    if (!response.ok) window.location.reload()
  }
}
