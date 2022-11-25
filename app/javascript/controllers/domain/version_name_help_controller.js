import {Controller} from "@hotwired/stimulus";
import bumpVersion from "semver-increment";

// https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
const semVerRegex = new RegExp('^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$')
const baseHelpText = "Next version name will be: "

export default class extends Controller {
  static values = {
    versionCurrent: String,
    disabled: Boolean,
  }

  static targets = [
    "input",
    "helpText",
  ]

  initialize() {
    this.__minorVerBump(this.versionCurrentValue);
  }

  bump() {
    this.__minorVerBump(this.inputTarget.value);
  }

  __minorVerBump(value) {
    if (this.disabledValue) {
      return;
    }

    if (value.length === 0) {
      this.helpTextTarget.innerHTML = ""
      return;
    }

    if (this.__isSemVer(value)) {
      this.helpTextTarget.innerHTML = baseHelpText + bumpVersion([0, 1, 0], value);
    } else {
      this.helpTextTarget.innerHTML = "Invalid semver format!"
    }
  }

  __isSemVer(value) {
    return semVerRegex.test(value)
  }
}
