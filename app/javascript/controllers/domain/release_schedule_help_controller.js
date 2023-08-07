import {Controller} from "@hotwired/stimulus";

const NEXT_RELEASE = "Your next release after the initial kickoff will be on: "

export default class extends Controller {
  static targets = ["kickoffDate", "nextDateNumber", "nextDateUnit", "output"];

  initialize() {
    this.change();
  }

  change() {
    if (this.__isEmptyInput()) {
      return;
    }
    const nextDateNumber = parseInt(this.nextDateNumberTarget.value);
    const nextDateUnit = this.nextDateUnitTarget.value;
    const kickoffDate = new Date(this.kickoffDateTarget.value);
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

  __isEmptyInput() {
    return this.kickoffDateTarget.value === "" ||
      this.nextDateUnitTarget.value === "" || this.nextDateNumberTarget.value === ""
  }

  __isValidDate(d) {
    return d instanceof Date && !isNaN(d);
  }
}
