import { Controller } from "@hotwired/stimulus"
import Choices from "choices.js"

export default class extends Controller {
  connect() {
    if (this.element.getAttribute("data-choice") !== "active") {
      this.choices = new Choices(this.element, {
        removeItemButton: this.element.multiple,
        shouldSort: false,
        shouldSortItems: false,
        itemSelectText: "",
      })
    }

    if (this.element.multiple) {
      this.setupOverflowControls()
    }
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.mutationObserver?.disconnect()
    this.innerElement?.removeEventListener("scroll", this.updateOverflowControls)
    this.element.removeEventListener("change", this.updateOverflowControls)
  }

  setupOverflowControls() {
    this.containerElement =
      this.element.closest(".choices") ||
      this.element.parentElement?.closest(".choices") ||
      this.element.nextElementSibling
    this.innerElement = this.containerElement?.querySelector(".choices__inner")
    if (!this.containerElement || !this.innerElement) return

    this.containerElement.classList.add("choices--with-scroll-buttons")
    this.containerElement.dataset.overflowLeft = "false"
    this.containerElement.dataset.overflowRight = "false"

    this.containerElement.querySelectorAll(".choices-scroll-button").forEach((button) => button.remove())

    this.leftButton = this.buildScrollButton("left", "\u2039")
    this.rightButton = this.buildScrollButton("right", "\u203A")
    this.containerElement.append(this.leftButton, this.rightButton)

    this.updateOverflowControls = this.updateOverflowControls?.bind(this) || this.refreshOverflowControls.bind(this)
    this.innerElement.addEventListener("scroll", this.updateOverflowControls)
    this.element.addEventListener("change", this.updateOverflowControls)

    this.resizeObserver = new ResizeObserver(this.updateOverflowControls)
    this.resizeObserver.observe(this.innerElement)
    this.resizeObserver.observe(this.containerElement)

    this.mutationObserver = new MutationObserver(() => {
      requestAnimationFrame(this.updateOverflowControls)
    })
    this.mutationObserver.observe(this.innerElement, { childList: true, subtree: true, characterData: true })

    requestAnimationFrame(this.updateOverflowControls)
    setTimeout(this.updateOverflowControls, 0)
  }

  buildScrollButton(direction, label) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = `choices-scroll-button choices-scroll-button--${direction}`
    button.textContent = label
    button.setAttribute("aria-label", `Scroll ${direction}`)
    button.addEventListener("click", () => {
      this.innerElement?.scrollBy({ left: direction === "left" ? -180 : 180, behavior: "smooth" })
    })
    return button
  }

  refreshOverflowControls() {
    if (!this.innerElement || !this.containerElement) return

    const maxScrollLeft = this.innerElement.scrollWidth - this.innerElement.clientWidth
    const currentScrollLeft = this.innerElement.scrollLeft
    this.containerElement.dataset.overflowLeft = String(currentScrollLeft > 4)
    this.containerElement.dataset.overflowRight = String(maxScrollLeft - currentScrollLeft > 4)
  }
}
