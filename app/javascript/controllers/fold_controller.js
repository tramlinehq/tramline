import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["foldable"]
  static values = {
    collapsed: String,
    expanded: String
  }

  connect() {
    if (this.hasFoldableTarget) {
      this.foldableTarget.classList.add(this.collapsedValue);
    }
  }

  toggle(event) {
    event.preventDefault();

    if (this.hasFoldableTarget) {
      this.foldableTarget.classList.toggle(this.expandedValue);
      this.foldableTarget.classList.toggle(this.collapsedValue);
    }
  }
}
