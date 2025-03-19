import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton", "spinner", "error"]
  static values = {
    nextStepUrl: String
  }

  connect() {
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("turbo:submit-start", this.startSubmit.bind(this))
      this.formTarget.addEventListener("turbo:submit-end", this.endSubmit.bind(this))
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("turbo:submit-start", this.startSubmit.bind(this))
      this.formTarget.removeEventListener("turbo:submit-end", this.endSubmit.bind(this))
    }
  }

  startSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.remove("hidden")
      }
    }
  }

  endSubmit(event) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.add("hidden")
      }
    }

    // If we got a successful response, we can move to the next step
    if (event.detail.success) {
      if (this.hasNextStepUrlValue) {
        Turbo.visit(this.nextStepUrlValue)
      }
    } else {
      // Show error message
      if (this.hasErrorTarget) {
        this.errorTarget.classList.remove("hidden")
        this.errorTarget.textContent = "There was an error saving your settings. Please try again."
      }
    }
  }
}