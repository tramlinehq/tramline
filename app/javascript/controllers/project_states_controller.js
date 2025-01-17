import { Controller } from "@hotwired/stimulus"
import { toggleDisplay } from "./helper"

export default class extends Controller {
  static targets = ["content"]

  toggle(event) {
    toggleDisplay(this.contentTarget, event.target.checked)
  }
}
