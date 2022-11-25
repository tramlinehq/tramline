import {Controller} from "@hotwired/stimulus";

const baseHelpText = "The next build number will be: "

export default class extends Controller {
  static values = {
    numberCurrent: Number,
  }

  static targets = [
    "input",
    "helpText",
  ]

  initialize() {
    this.__increment(this.numberCurrentValue);
  }

  increment() {
    this.__increment(parseInt(this.inputTarget.value));
  }

  __increment(value) {
    console.log(value);

    if (this.__isNumeric(value)) {
      this.helpTextTarget.innerHTML = baseHelpText + ++value;
    } else {
      this.helpTextTarget.innerHTML = "Build numbers can only be positive integers!";
    }
  }

  __isNumeric(value) {
    return !isNaN(value) && !isNaN(parseFloat(value));
  }
}
