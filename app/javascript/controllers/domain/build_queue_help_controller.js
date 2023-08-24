import {Controller} from "@hotwired/stimulus";

const BASE_HELP_TEXT = "Changes will be applied to the release every "
const ERR_HELP_TEXT = "You must set a valid build queue config when it is enabled"

export default class extends Controller {
  static targets = ["checkbox", "config", "size", "waitTimeValue", "waitTimeUnit", "output", "errOutput"];

  initialize() {
    this.change();
  }

  change() {
    this.__resetContents()

    const buildQueueEnabled = (this.checkboxTarget.checked === true)
    const buildQueueDisabled = ((this.checkboxTarget.checked === false))

    if (buildQueueEnabled) {
      this.configTarget.hidden = false
    }

    if (buildQueueDisabled) {
      this.configTarget.hidden = true
    }

    if (this.__isEmptyConfig() && buildQueueDisabled) {
      return;
    }

    if (this.__isEmptyConfig() && buildQueueEnabled) {
      this.errOutputTarget.textContent = ERR_HELP_TEXT
      return;
    }

    const size = this.sizeTarget.value
    const waitTimeUnit = this.waitTimeUnitTarget.value
    const waitTimeValue = this.waitTimeValueTarget.value

    this.outputTarget.textContent = `${BASE_HELP_TEXT}${waitTimeValue} ${waitTimeUnit} OR ${size} commits`
  }

  __resetContents() {
    this.configTarget.hidden = true
    this.errOutputTarget.textContent = ""
    this.outputTarget.textContent = ""
  }

  __isEmptyConfig() {
    return this.sizeTarget.value === "" || this.waitTimeUnitTarget.value === "" || this.waitTimeValueTarget.value === ""
  }
}
