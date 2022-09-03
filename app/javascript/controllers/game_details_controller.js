import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document
      .querySelectorAll("#game-details__description p img")
      .forEach((el) => el.setAttribute("class", "img-fluid"))
  }
}
