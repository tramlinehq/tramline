import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "subsection"]

  connect() {
    this.sectionTargets.forEach((section) => this.targetedToggle(section))
  }

  toggle(e) {
    this.targetedToggle(e.target)
  }

  targetedToggle(target) {
    let subsection = this.subsectionTargets.find(t => t.dataset.sectionKey === target.dataset.sectionKey)
    if (subsection) {
      subsection.hidden = !target.checked
    }
  }
}
