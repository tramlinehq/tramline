import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "content", "indicator", "nextButton", "prevButton", "progress"]
  static values = {
    currentStep: Number,
    totalSteps: Number
  }

  connect() {
    this.showCurrentStep()
    this.updateProgress()
  }

  showCurrentStep() {
    this.stepTargets.forEach((step, index) => {
      step.classList.toggle("active", index === this.currentStepValue)
      step.classList.toggle("completed", index < this.currentStepValue)
      
      // Update step indicators
      const indicator = this.indicatorTargets[index]
      if (index < this.currentStepValue) {
        indicator.classList.remove("bg-gray-200", "bg-blue-500")
        indicator.classList.add("bg-green-500")
      } else if (index === this.currentStepValue) {
        indicator.classList.remove("bg-gray-200", "bg-green-500")
        indicator.classList.add("bg-blue-500")
      } else {
        indicator.classList.remove("bg-blue-500", "bg-green-500")
        indicator.classList.add("bg-gray-200")
      }
    })

    this.contentTargets.forEach((content, index) => {
      content.classList.toggle("hidden", index !== this.currentStepValue)
    })

    // Update button states
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.classList.toggle("invisible", this.currentStepValue === 0)
    }
    
    if (this.hasNextButtonTarget) {
      const isLastStep = this.currentStepValue === this.totalStepsValue - 1
      this.nextButtonTarget.textContent = isLastStep ? "Complete Setup" : "Next Step"
      this.nextButtonTarget.classList.toggle("bg-green-600", isLastStep)
      this.nextButtonTarget.classList.toggle("bg-blue-600", !isLastStep)
    }
  }

  updateProgress() {
    if (this.hasProgressTarget) {
      const percent = Math.round((this.currentStepValue / (this.totalStepsValue - 1)) * 100)
      this.progressTarget.style.width = `${percent}%`
      this.progressTarget.setAttribute("aria-valuenow", percent)
    }
  }

  next() {
    if (this.currentStepValue < this.totalStepsValue - 1) {
      this.currentStepValue++
      this.showCurrentStep()
      this.updateProgress()
    }
  }

  prev() {
    if (this.currentStepValue > 0) {
      this.currentStepValue--
      this.showCurrentStep()
      this.updateProgress()
    }
  }

  navigateTo(event) {
    const stepIndex = parseInt(event.currentTarget.dataset.stepIndex)
    if (stepIndex <= this.currentStepValue || this.isStepAccessible(stepIndex)) {
      this.currentStepValue = stepIndex
      this.showCurrentStep()
      this.updateProgress()
    }
  }

  isStepAccessible(stepIndex) {
    // A step is accessible if all previous steps are completed
    // This would be based on form validation or completed flags
    return this.stepTargets.slice(0, stepIndex).every(step => 
      step.classList.contains("completed"))
  }
}