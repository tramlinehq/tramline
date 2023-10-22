import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    version: String,
    versionSuffixCurrent: String,
    prefix: String
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
    if (suffix !== "") {
      this.helpTextTarget.innerHTML = this.prefixValue + this.versionValue + "-" + suffix;
    } else {
      this.helpTextTarget.innerHTML = this.prefixValue + this.versionValue;
    }
  }
}
