import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["visible"]

  initialize() {
    this.visibleTarget.style.visibility = "hidden"
  }

  toggle() {
    if (this.visibleTarget.style.visibility === "hidden") {
      this.visibleTarget.style.visibility = "visible";
    } else {
      this.visibleTarget.style.visibility = "hidden";
    }
  }
}
