import {Controller} from "@hotwired/stimulus";

const errorMessage = "Total weight must be 100%"

export default class extends Controller {
  static targets = ["weight", "total", "errorMessage"]

  static values = {
    errorClasses: Array
  }

  connect() {
    this.computeTotal()
  }

  computeTotal() {
    let totalWeight = 0
    this.weightTargets.forEach((weight) => {
      totalWeight += parseInt(weight.value)
    })
    this.totalTarget.textContent = totalWeight + "%"
    let errorClasses = this.errorClassesValue
    if (totalWeight !== 100) {
      errorClasses.forEach((errorClass) => {
        this.totalTarget.classList.add(errorClass)
      })
      this.errorMessageTarget.textContent = errorMessage
    } else {
      errorClasses.forEach((errorClass) => {
        this.totalTarget.classList.remove(errorClass)
      })
      this.errorMessageTarget.textContent = ""
    }
  }
}
