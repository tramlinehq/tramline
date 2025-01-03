import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    baseString: String,
    separator: { type: String, default: "-" },
    commonPrefix: String,
  }

  static targets = [
    "suffixInput",
    "prefixInput",
    "helpText",
  ]

  initialize() {
    this.__set();
  }

  set() {
    this.__set();
  }

  __set() {
    const prefix = this.prefixInputTarget.value;
    const suffix = this.suffixInputTarget.value;
    const baseString = this.baseStringValue;
    const separator = this.separatorValue;
    const commonPrefix = this.commonPrefixValue;

    let result = `${commonPrefix}${baseString}`;
    if (prefix) {
      result = `${prefix}${separator}${result}`;
    }
    if (suffix) {
      result = `${result}${separator}${suffix}`;
    }

    this.helpTextTarget.textContent = result;
  }
}
