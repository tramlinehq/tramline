import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["tooltip"]

  show() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.remove("hidden")
    }
  }

  hide() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }

  disconnect() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.remove()
    }
  }
}
