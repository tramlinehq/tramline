import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["target"]
  static values = {
    active: String,
    inactive: String
  }

  toggle(event) {
    this.targetTargets.forEach(t => {
      if (t === event.target) {
        t.className = this.activeValue;
      } else {
        t.className = this.inactiveValue;
      }
    });
  }
}
