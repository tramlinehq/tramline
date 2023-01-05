import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["visible"]

  initialize() {
    if (this.hasVisibleTarget) {
      this.visibleTarget.style.visibility = "hidden"
    }
  }

  toggle() {
    if (this.hasVisibleTarget) {
      if (this.visibleTarget.style.visibility === "hidden") {
        this.visibleTarget.style.visibility = "visible";
      } else {
        this.visibleTarget.style.visibility = "hidden";
      }
    }
  }
}
