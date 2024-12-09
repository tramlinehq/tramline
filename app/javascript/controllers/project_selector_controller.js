import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["config", "filterDivider"]

  connect() {
    this.toggleConfigurations()
    this.toggleFilterDivider()
  }

  toggle(event) {
    this.toggleConfigurations()
    this.toggleFilterDivider()
  }

  toggleConfigurations() {
    const configs = document.querySelectorAll('.project-config')
    configs.forEach(config => {
      const projectKey = config.dataset.project
      const checkbox = document.querySelector(`#project_${projectKey}`)
      if (checkbox) {
        config.style.display = checkbox.checked ? 'block' : 'none'
      }
    })
  }

  toggleFilterDivider() {
    const anyProjectSelected = Array.from(document.querySelectorAll('input[name^="app_config[jira_config][selected_projects]"]'))
      .some(checkbox => checkbox.checked)

    if (this.hasFilterDividerTarget) {
      this.filterDividerTarget.style.display = anyProjectSelected ? 'block' : 'none'
      this.filterDividerTarget.classList.add('border-t')
      this.filterDividerTarget.classList.add('border-b')
    }
  }
}
