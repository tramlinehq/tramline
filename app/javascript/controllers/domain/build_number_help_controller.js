import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    number: Number,
  }

  static targets = [
    "input",
    "helpText",
  ]

  initialize() {
    this.__increment(this.numberValue);
  }

  increment() {
    this.__increment(parseInt(this.inputTarget.value || this.numberValue));
  }

  __increment(value) {
    this.helpTextTarget.innerHTML = ++value;
  }
}
