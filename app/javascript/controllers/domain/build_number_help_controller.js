import {Controller} from "@hotwired/stimulus";

const initialHelpNotice = "Enter a positive integer as your build number. This would typically be your last versionCode."
const baseHelpText = "The next build number will be:"

export default class extends Controller {
  static values = {
    numberCurrent: String,
  }

  static targets = [
    "input",
    "helpTextTitle",
    "helpTextVal"
  ]

  initialize() {
    this.__increment(this.numberCurrentValue);
  }

  increment() {
    this.__increment(this.inputTarget.value);
  }

  __increment(value) {
    if (value.length === 0) {
      this.helpTextTitleTarget.innerHTML = initialHelpNotice;
      this.helpTextValTarget.innerHTML = "";
      return;
    }

    let intValue = parseInt(value);

    if (this.__isNumeric(intValue)) {
      this.helpTextTitleTarget.innerHTML = baseHelpText;
      this.helpTextValTarget.innerHTML = ++intValue;
    }
  }

  __isNumeric(value) {
    return !isNaN(value) && !isNaN(parseFloat(value));
  }
}
