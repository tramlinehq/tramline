import {Controller} from "@hotwired/stimulus";

const BASE_HELP_TEXT = "Changes will be applied to the release every "
const ERR_HELP_TEXT = "You must set a valid build queue config when it is enabled"

export default class extends Controller {
  static targets = ["checkbox", "size", "waitTimeValue", "waitTimeUnit", "output", "errOutput"]
  static values = {
    branchingStrategy: String
  }

  initialize() {
    this.change();
  }

  branchingStrategyValueChanged() {
    this.change();
  }

  change() {
    this.__resetContents()

    const buildQueueEnabled = (this.checkboxTarget.checked === true)
    const buildQueueDisabled = ((this.checkboxTarget.checked === false))

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

    if (this.branchingStrategyValue === "trunk") {
      this.outputTarget.textContent = "Changes will be applied manually"
      this.__changeInputStates(true)
    } else {
      this.outputTarget.textContent = `${BASE_HELP_TEXT}${waitTimeValue} ${waitTimeUnit} OR ${size} commits`
      this.__changeInputStates(false)
    }
  }

  __resetContents() {
    this.errOutputTarget.textContent = ""
    this.outputTarget.textContent = ""
  }

  __isEmptyConfig() {
    return this.sizeTarget.value === "" || this.waitTimeUnitTarget.value === "" || this.waitTimeValueTarget.value === ""
  }

  __changeInputStates(enabled) {
    this.sizeTarget.disabled = enabled
    this.waitTimeValueTarget.disabled = enabled
    this.waitTimeUnitTarget.disabled = enabled
  }
}
