import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    version: String,
    versionSuffixCurrent: String
  }

  static targets = [
    "input",
    "helpText",
  ]

  initialize() {
    this.__set(this.versionSuffixCurrentValue);
  }

  set() {
    this.__set(this.inputTarget.value);
  }

  __set(suffix) {
    this.helpTextTarget.innerHTML = this.versionValue + "-" + suffix;
  }
}

