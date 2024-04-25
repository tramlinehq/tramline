import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["weight", "total", "errorMessage"]

  connect() {
    this.computeTotal()
  }

  computeTotal() {
    let totalWeight = 0
    this.weightTargets.forEach((weight) => {
      totalWeight += parseInt(weight.value)
    })
    this.totalTarget.textContent = totalWeight + "%"
    if (totalWeight !== 100) {
      this.totalTarget.classList.add("text-red-600", "dark:text-red-400")
      this.errorMessageTarget.textContent = "Total weight must be 100%"
    } else {
      this.totalTarget.classList.remove("text-red-600", "dark:text-red-400")
      this.errorMessageTarget.textContent = ""
    }
  }
}
