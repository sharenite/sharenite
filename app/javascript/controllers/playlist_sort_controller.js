import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "order"]
  static values = { url: String }

  connect() {
    this.draggedRow = null
  }

  start(event) {
    const row = event.currentTarget.closest("[data-playlist-sort-target='row']")
    if (!row) return

    this.draggedRow = row
    row.classList.add("playlist-sort-row-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", row.dataset.playlistItemId)
  }

  over(event) {
    event.preventDefault()
    const targetRow = event.currentTarget.closest("[data-playlist-sort-target='row']")
    if (!this.draggedRow || targetRow === this.draggedRow) return

    const midpoint = targetRow.getBoundingClientRect().top + (targetRow.offsetHeight / 2)
    const insertAfter = event.clientY > midpoint

    if (insertAfter) {
      targetRow.parentNode.insertBefore(this.draggedRow, targetRow.nextSibling)
    } else {
      targetRow.parentNode.insertBefore(this.draggedRow, targetRow)
    }
  }

  end() {
    if (!this.draggedRow) return

    this.draggedRow.classList.remove("playlist-sort-row-dragging")
    this.draggedRow = null
    this.refreshOrderNumbers()
    this.persistOrder()
  }

  refreshOrderNumbers() {
    this.rowTargets.forEach((row, index) => {
      const orderElement = row.querySelector("[data-playlist-sort-order]")
      if (orderElement) orderElement.textContent = index + 1
    })
  }

  async persistOrder() {
    if (!this.hasUrlValue) return

    const orderedIds = this.rowTargets.map((row) => row.dataset.playlistItemId)
    const token = document.querySelector("meta[name='csrf-token']")?.content

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ ordered_ids: orderedIds })
    })

    if (!response.ok) {
      window.location.reload()
    }
  }
}
