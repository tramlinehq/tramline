import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container", "filter"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/__INDEX__/g, this.filterTargets.length)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const filter = event.target.closest("[data-domain--release-filters-target='filter']")
    filter.remove()
  }
}
