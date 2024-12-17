import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["primary", "secondary"]

  initialize() {
    this.updateDependentState()
  }

  change() {
    this.updateDependentState()
  }

  updateDependentState() {
    this.secondaryTarget.disabled = this.primaryTarget.checked;
    this.primaryTarget.disabled = this.secondaryTarget.checked;
  }
}
