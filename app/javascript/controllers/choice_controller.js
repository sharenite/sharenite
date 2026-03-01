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
  }
}
