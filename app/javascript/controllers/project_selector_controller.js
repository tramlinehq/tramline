import { Controller } from "@hotwired/stimulus"
import { toggleDisplay } from "./helper"

export default class extends Controller {
  static targets = [ "projectCheckbox", "config", "filterDivider"]

  connect() {
    this.toggleConfigurations()
    this.toggleFilterDivider()
  }

  toggle() {
    this.toggleConfigurations()
    this.toggleFilterDivider()
  }

  toggleConfigurations() {
    const configs = document.querySelectorAll('.project-config')
    configs.forEach(config => {
      const projectKey = config.dataset.project
      const checkbox = document.querySelector(`#project_${projectKey}`)
      if (checkbox) {
        toggleDisplay(config, checkbox.checked)
      }
    })
  }

  toggleFilterDivider() {
    const anyProjectSelected = this.projectCheckboxTargets.some(checkbox => checkbox.checked)

    if (this.hasFilterDividerTarget) {
      toggleDisplay(this.filterDividerTarget, anyProjectSelected)
      this.filterDividerTarget.classList.add('border-t')
      this.filterDividerTarget.classList.add('border-b')
    }
  }
}
