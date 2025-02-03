import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "subsection", "emptyState"]
  static outlets = ["reveal"]

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

    this.updateEmptiness()
  }

  updateEmptiness() {
    if (this.hasRevealOutlet) {
      if (this.subsectionTargets.every(t => t.hidden)) {
        this.revealOutlet.show()
      } else {
        this.revealOutlet.hide()
      }
    }
  }
}
