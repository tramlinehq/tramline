import {Controller} from "@hotwired/stimulus";
import bumpVersion from "semver-increment";

const compatibilityMessage = "Only MAJOR.MINOR.PATCH or MAJOR.MINOR supported. Each term should only be numbers."
const semVerRegex = new RegExp('^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:\\.(0|[1-9]\\d*))?$')
const emptyVersion = "X.X"

export default class extends Controller {
  static values = {
    disabled: Boolean,
  }

  static targets = [
    "majorInput",
    "minorInput",
    "patchInput",
    "nextVersion",
    "currentVersion",
    "helpTextVal",
    "freezeReleaseVersion"
  ]

  initialize() {
    this.majorVersion = ""
    this.minorVersion = ""
    this.patchVersion = ""
    if(this.hasHelpTextValTarget) {
      this.helpTextValTarget.hidden = true
    }
  }

  bump() {
    if (this.disabledValue) {
      return;
    }

    this.majorVersion = this.majorInputTarget.value
    this.minorVersion = this.minorInputTarget.value
    this.patchVersion = this.patchInputTarget.value

    this.__verChange();
  }

  __verChange() {
    if (!this.__isSemVer(this.__versionString())) {
      this.helpTextValTarget.hidden = false
      this.helpTextValTarget.innerHTML = compatibilityMessage
      this.nextVersionTarget.innerHTML = emptyVersion
      this.currentVersionTarget.innerHTML = emptyVersion
    } else {
      this.helpTextValTarget.hidden = true;
      this.nextVersionTarget.innerHTML = this.__nextReleaseVersion()
      this.currentVersionTarget.innerHTML = this.__versionString()
    }
  }

  __isSemVer(value) {
    return semVerRegex.test(value)
  }

  __nextReleaseVersion() {
    try {
      if (this.freezeReleaseVersionTarget.checked) {
        return this.__versionString();
      }
      return bumpVersion([0, 1, 0], this.__versionString())
    } catch (error) {
      return emptyVersion
    }
  }

  __versionString() {
    if (this.__allButMinorMissing()) {
      return emptyVersion
    } else {
      return this.__compactArray([this.majorVersion, this.minorVersion, this.patchVersion]).join(".")
    }
  }

  __compactArray(arr) {
    return arr.filter(item => this.__is_present(item))
  }

  __is_present(item) {
    return item !== "" && item !== null && item !== undefined
  }

  __allButMinorMissing() {
    return this.__is_present(this.majorVersion) && this.__is_present(this.patchVersion) && !this.__is_present(this.minorVersion)
  }

  updateVersion() {
    if (this.hasNextVersionTarget && this.__isSemVer(this.__versionString())) {
      if (this.freezeReleaseVersionTarget.checked) {
        this.nextVersionTarget.innerHTML = this.__versionString();
      } else {
        this.nextVersionTarget.innerHTML = this.__nextReleaseVersion();
      }
    }
  }
}
