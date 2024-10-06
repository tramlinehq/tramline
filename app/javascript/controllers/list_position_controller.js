import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["position", "showCheckbox"]

  static values = {
    initial: Number,
  }

  update() {
    let position = this.initialValue
    for (let posTarget of this.positionTargets) {
      posTarget.value = position
      position++
    }
    if (this.hasShowCheckboxTarget) {
      this.showCheckboxTarget.hidden = position <= 2;
    }
  }
}
