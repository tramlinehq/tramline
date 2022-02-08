import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "hideable" ]

  showTargets() {
    this.hideableTargets.forEach(el => {
      el.hidden = false
    });
  }

  hideTargets() {
    this.hideableTargets.forEach(el => {
      el.hidden = true
    });
  }

  toggleTargets() {
    this.hideableTargets.forEach((el) => {
      el.hidden = !el.hidden
    });
  }
}