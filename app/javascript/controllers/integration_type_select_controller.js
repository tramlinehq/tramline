import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "section"]

  connect() {
    this.showSelectedSection()
  }

  change() {
    this.showSelectedSection()
  }

  showSelectedSection() {
    const selectedType = this.typeSelectTarget.value

    this.sectionTargets.forEach((section) => {
      if (section.dataset.integrationType === selectedType) {
        section.hidden = false
        this.enableInputs(section)
      } else {
        section.hidden = true
        this.disableInputs(section)
      }
    })
  }

  enableInputs(section) {
    section.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = false
    })
  }

  disableInputs(section) {
    section.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = true
    })
  }
}
