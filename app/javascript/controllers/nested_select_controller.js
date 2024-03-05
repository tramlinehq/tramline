import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary", "nested"]

  static values = { selectedOption: String }

  connect() {
    this.updateNestedOptions()
  }

  updateNestedOptions() {
    const selectedValue = JSON.parse(this.primaryTarget.selectedOptions[0].value)

    this.populateNestedDropdowns(selectedValue.release_stages)

  }

  populateNestedDropdowns(options) {
    for(let target of this.nestedTargets) {
      target.innerHTML = options.map((option) => this.__createOption(option)).join("");
    }
  }

  __createOption(option) {
      return `<option value=${JSON.stringify(option)} ${(this.selectedOptionValue !== "" && this.selectedOptionValue === option) ? "selected" : ""}>${option}</option>`
  }
}
