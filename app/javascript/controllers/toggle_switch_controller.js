import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "output"]
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
    } else {
      this.outputTarget.innerHTML = this.offLabelValue
    }
  }
}
