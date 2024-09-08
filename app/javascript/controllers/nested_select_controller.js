import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary", "nested"]

  static values = {
    selectedNestedOption: String,
    options: Array
  }

  connect() {
    this.updateNestedOptions()
  }

  updateNestedOptions() {
    const selectedValue = JSON.parse(this.primaryTarget.selectedOptions[0].value)
    const releaseStages = this.optionsValue.find((option) => option.id === selectedValue.id).release_stages
    this.populateNestedDropdowns(releaseStages)
  }

  populateNestedDropdowns(options) {
    for (let target of this.nestedTargets) {
      target.innerHTML = options.map((option) => this.__createOption(option)).join("");
    }
  }

  __createOption(option) {
    return `<option value=${JSON.stringify(option)} ${(this.selectedNestedOptionValue !== "" && this.selectedNestedOptionValue === option) ? "selected" : ""}>${option}</option>`
  }
}
