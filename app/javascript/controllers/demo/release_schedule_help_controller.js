import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["nextDateNumber", "nextDateUnit", "output"];

  initialize() {
    this.change();
  }

  change() {
    const nextDateNumber = parseInt(this.nextDateNumberTarget.value);
    const nextDateUnit = this.nextDateUnitTarget.value;
    const currentDateObj = new Date();
    const nextDate = new Date(currentDateObj);

    switch (nextDateUnit) {
      case 'day(s)':
        nextDate.setDate(currentDateObj.getDate() + nextDateNumber);
        break;
      case 'week(s)':
        nextDate.setDate(currentDateObj.getDate() + nextDateNumber * 7);
        break;
      case 'month(s)':
        nextDate.setMonth(currentDateObj.getMonth() + nextDateNumber);
        break;
      default:
        return;
    }

    this.outputTarget.textContent = nextDate.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }
}
