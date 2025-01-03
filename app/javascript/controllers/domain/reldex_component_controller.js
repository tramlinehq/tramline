import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["weight", "inactive"]

  connect() {
    this.markActionable()
  }

  markActionable() {
    let weight = parseFloat(this.weightTarget.value)
    this.inactiveTarget.hidden = weight !== 0;
  }
}
