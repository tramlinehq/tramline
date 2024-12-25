import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "output", "child"]
  static values = {
    onLabel: {type: String, default: "On"},
    offLabel: {type: String, default: "Off"}
  }

  initialize() {
    this.change()
  }

  change() {
    if (this.checkboxTarget.checked) {
      this.outputTarget.innerHTML = this.onLabelValue
      if (this.hasChildTarget) {
        this.childTargets.forEach((child) => (child.hidden = false));
      }
    } else {
      this.outputTarget.innerHTML = this.offLabelValue
      if (this.hasChildTarget) {
        this.childTargets.forEach((child) => (child.hidden = true));
      }
    }
  }
}
