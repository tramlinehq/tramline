import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle(event) {
    this.contentTarget.style.display = event.target.checked ? "block" : "none"
  }
}
