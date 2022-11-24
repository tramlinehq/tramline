import {Controller} from "@hotwired/stimulus";

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
    this.__increment(parseInt(this.inputTarget.value || this.numberCurrentValue));
  }

  __increment(value) {
    this.helpTextTarget.innerHTML = ++value;
  }
}
