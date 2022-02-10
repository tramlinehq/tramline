import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["visible"]

  initialize() {
    this.visibleTarget.style.display = "none"
  }

  toggle() {
    if (this.visibleTarget.style.display === "none") {
      this.visibleTarget.style.display = "block";
    } else {
      this.visibleTarget.style.display = "none";
    }
  }
}
