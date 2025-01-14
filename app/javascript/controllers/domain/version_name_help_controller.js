import {Controller} from "@hotwired/stimulus";
import {default as bumpSemVer} from "semver-increment";

const semVerCompatibilityMessage = "Only MAJOR.MINOR.PATCH or MAJOR.MINOR supported. Each term should only be numbers."
const calVerCompatibilityMessage = "Only YYYY.0M.0D supported. Month and Day terms should be zero-padded."
const semVerRegex = new RegExp('^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:\\.(0|[1-9]\\d*))?$')
const calVerRegex = new RegExp('^([1-9]\\d{3})\\.(0[1-9]|1[0-2])\\.(0[1-9]|[12]\\d|3[01])(0[1-9]|[1-9]\\d)?$')
const emptyVersion = "X.X"

export default class extends Controller {
  static values = {
    disabled: Boolean,
    strategy: {type: String, default: "semver"}
  }

  static targets = [
    "majorInput",
    "minorInput",
    "patchInput",
    "nextVersion",
    "currentVersion",
    "helpTextVal",
    "freezeReleaseVersion",
    "versioningStrategy"
  ]

  initialize() {
    this.currentStrategy = this.strategyValue
    this.majorVersion = ""
    this.minorVersion = ""
    this.patchVersion = ""
    if (this.hasHelpTextValTarget) {
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

    this.__verChange()
  }

  updateStrategy() {
    this.currentStrategy = this.versioningStrategyTarget.value
    this.__verChange()
  }

  updateVersion() {
    if (this.hasNextVersionTarget && this.__isValidSemVer(this.__versionString())) {
      if (this.freezeReleaseVersionTarget.checked) {
        this.nextVersionTarget.innerHTML = this.__versionString();
      } else {
        this.nextVersionTarget.innerHTML = this.__nextReleaseVersion();
      }
    }
  }

  __verChange() {
    let validVersion = false
    let compatibilityMessage = ""

    if (this.__semVerStrategy()) {
      validVersion = this.__isValidSemVer(this.__versionString())
      compatibilityMessage = semVerCompatibilityMessage
    }

    if (this.__calVerStrategy()) {
      validVersion = this.__isValidCalVer(this.__versionString())
      compatibilityMessage = calVerCompatibilityMessage
    }

    if (!validVersion) {
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

  __nextReleaseVersion() {
    try {
      if (this.freezeReleaseVersionTarget.checked) {
        return this.__versionString();
      }
      return this.__bumpVer()
    } catch (error) {
      return emptyVersion
    }
  }

  __bumpVer() {
    if (this.__semVerStrategy()) {
      return bumpSemVer([0, 1, 0], this.__versionString())
    }

    if (this.__calVerStrategy()) {
      const today = new Date();
      const year = today.getFullYear();
      const month = String(today.getMonth() + 1).padStart(2, '0');
      const day = String(today.getDate()).padStart(2, '0');

      return `${year}.${month}.${day}`;
    }
  }

  // Utils

  __isValidSemVer(value) {
    return semVerRegex.test(value)
  }

  __isValidCalVer(value) {
    return calVerRegex.test(value)
  }

  __semVerStrategy() {
    return this.currentStrategy === "semver"
  }

  __calVerStrategy() {
    return this.currentStrategy === "calver"
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
}
