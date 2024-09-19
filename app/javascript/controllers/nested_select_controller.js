import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary", "nested"]

  static values = {
    selectedNestedOption: String,
    options: Array,
    optionKey: "id",
    nestedOptionKey: "release_stages",
    nestedOptionsId: "id",
    nestedOptionsName: "name"
  }

  connect() {
    this.updateNestedOptions()
  }

  updateNestedOptions() {
    const selectedValue = this.__safeJSONParse(this.primaryTarget.selectedOptions[0].value)
    let possibleOptions
    if (typeof selectedValue === "string") {
      possibleOptions = this.optionsValue.find((option) => option[this.optionKeyValue] === selectedValue)[this.nestedOptionKeyValue]
    } else {
      possibleOptions = this.optionsValue.find((option) => option[this.optionKeyValue] === selectedValue[this.optionKeyValue])[this.nestedOptionKeyValue]
    }
    this.populateNestedDropdowns(possibleOptions)
  }

  populateNestedDropdowns(options) {
    for (let target of this.nestedTargets) {
      target.innerHTML = options.map((option) => this.__createOption(option)).join("");
    }
  }

  __createOption(option) {
    if (typeof option === "string") {
      return `<option value=${JSON.stringify(option)} ${(this.selectedNestedOptionValue !== "" && this.selectedNestedOptionValue === option) ? "selected" : ""}>${option}</option>`
    }
    const option_val = option[this.nestedOptionsIdValue]
    const option_name = option[this.nestedOptionsNameValue]
    return `<option value=${JSON.stringify(option_val)} ${(this.selectedNestedOptionValue !== "" && this.selectedNestedOptionValue === option_val) ? "selected" : ""}>${option_name}</option>`
  }

  __safeJSONParse(str) {
    let parsedJSON = null;

    try {
      parsedJSON = JSON.parse(str);
    } catch (e) {
      return str;
    }

    return parsedJSON;
  }

}
