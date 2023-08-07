import {Controller} from "@hotwired/stimulus";

const NEXT_RELEASE = "Your next release after the initial kickoff will be on – "

export default class extends Controller {
  static targets = ["kickoffDate", "nextDateNumber", "nextDateUnit", "output", "errOutput"];

  initialize() {
    this.change();
  }

  change() {
    this.__resetContents()

    if (this.__isEmptyInput()) {
      return;
    }

    const nextDateNumber = parseInt(this.nextDateNumberTarget.value);
    const kickoffDate = new Date(this.kickoffDateTarget.value);

    if (this.__invalidRepeatDuration(nextDateNumber)) {
      this.errOutputTarget.textContent = "Invalid repeat duration, please choose a duration >= 1 day & <= 365 days"
      return
    }

    if (this.__invalidKickoffDate(kickoffDate)) {
      this.errOutputTarget.textContent = "The initial scheduled kickoff for the train should be in the future"
      return
    }

    const nextDateUnit = this.nextDateUnitTarget.value;
    const nextDate = new Date(kickoffDate);

    switch (nextDateUnit) {
      case 'days':
        nextDate.setDate(kickoffDate.getDate() + nextDateNumber);
        break;
      case 'weeks':
        nextDate.setDate(kickoffDate.getDate() + nextDateNumber * 7);
        break;
      default:
        return;
    }

    if (this.__isValidDate(nextDate)) {
      this.outputTarget.textContent = NEXT_RELEASE + nextDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
    }
  }

  resetSchedule() {
    this.kickoffDateTarget.value = null
    this.nextDateNumberTarget.value = null
  }

  __resetContents() {
    this.outputTarget.textContent = ""
    this.errOutputTarget.textContent = ""
  }

  __isEmptyInput() {
    return this.kickoffDateTarget.value === "" ||
      this.nextDateUnitTarget.value === "" || this.nextDateNumberTarget.value === ""
  }

  __isValidDate(d) {
    return d instanceof Date && !isNaN(d);
  }

  __invalidKickoffDate(d) {
    return d < new Date()
  }

  __invalidRepeatDuration(n) {
    if (typeof n !== 'number') {
      return true
    }

    return n < 1 || n > 365
  }
}
