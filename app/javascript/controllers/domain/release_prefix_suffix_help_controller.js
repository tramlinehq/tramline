import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    version: String,
    versionPrefixCurrent: String,
    versionSuffixCurrent: String,
    prefix: String
  }

  static targets = [
    "suffixInput",
    "helpText",
    "prefixInput"
  ]

  initialize() {
    this.__set(this.versionPrefixCurrentValue, this.versionSuffixCurrentValue);
  }

  set() {
    this.__set(this.prefixInputTarget.value, this.suffixInputTarget.value);
  }

  __set(prefix, suffix) {
    let releaseTag = this.prefixValue + this.versionValue;
    if (prefix !== "") {
      releaseTag = prefix + "-" + releaseTag;
    }
    if (suffix !== "") {
      releaseTag = releaseTag + "-" + suffix;
    }
    this.helpTextTarget.innerHTML = releaseTag;
  }
}
