import {Controller} from "@hotwired/stimulus";

const ERR_HELP_TEXT = "You must set a valid release schedule config when it is enabled"

export default class extends Controller {
  static targets = ["checkbox", "config", "kickoffDate", "nextDateNumber", "nextDateUnit", "output", "errOutput"];
  static values = {timezone: String};

  initialize() {
    this.change();
  }

  change() {
    this.__resetContents()
    this.kickoffDateTarget.setCustomValidity("")

    const enabled = (this.checkboxTarget.checked === true)
    const disabled = (this.checkboxTarget.checked === false)

    if (disabled) {
      this.__resetInput()
    }

    if (this.__isEmptyInput() && disabled) {
      return
    }

    if (this.__isEmptyInput() && enabled) {
      this.errOutputTarget.textContent = ERR_HELP_TEXT
      return
    }

    const nextDateNumber = parseInt(this.nextDateNumberTarget.value);
    const kickoffDate = new Date(this.kickoffDateTarget.value);

    if (this.__invalidRepeatDuration(nextDateNumber)) {
      this.errOutputTarget.textContent = "Invalid repeat duration, please choose a duration >= 1 day & <= 365 days"
      return
    }

    const nextDateUnit = this.nextDateUnitTarget.value;
    const unitLabel = nextDateUnit === 'weeks' ? 'week' : 'day';
    const interval = nextDateNumber === 1 ? `1 ${unitLabel}` : `${nextDateNumber} ${unitLabel}s`;
    const kickoffFormatted = kickoffDate.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    this.outputTarget.textContent = `Releases will run every ${interval} after the initial kickoff on ${kickoffFormatted}`;
  }

  __resetContents() {
    this.outputTarget.textContent = ""
    this.errOutputTarget.textContent = ""
  }

  __isEmptyInput() {
    return this.kickoffDateTarget.value === "" ||
      this.nextDateUnitTarget.value === "" || this.nextDateNumberTarget.value === ""
  }

  __resetInput() {
    this.kickoffDateTarget.value = ""
    this.nextDateUnitTarget.value = "days"
    this.nextDateNumberTarget.value = ""
  }

  __isValidDate(d) {
    return d instanceof Date && !isNaN(d);
  }

  showKickoffError(event) {
    const input = event.target;
    if (input.validity.rangeUnderflow) {
      input.setCustomValidity(`The kickoff should be in the future (${this.timezoneValue})`);
    }
  }

  __invalidRepeatDuration(n) {
    if (typeof n !== 'number') {
      return true
    }

    return n < 1 || n > 365
  }
}
