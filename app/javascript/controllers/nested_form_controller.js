import { Controller } from "stimulus"
import Choices from 'choices.js'

export default class extends Controller {
  static targets = ["add_item", "template"]

  initialize() {
    this.reset_choices()
  }

  add_association(event) {
    event.preventDefault()
    var content = this.templateTarget.innerHTML.replace(/TEMPLATE_RECORD/g, new Date().valueOf())
    this.add_itemTarget.insertAdjacentHTML("beforebegin", content)
    this.reset_choices()
  }

  remove_association(event) {
    event.preventDefault()
    let item = event.target.closest(".nested-fields")
    item.querySelector("input[name*='_destroy']").value = 1
    item.style.display = 'none'
  }

  reset_choices() {
    let elements = [...document.querySelectorAll('.js-choice')].map(el => new Choices(el, { allowHTML: false }))
	}
}
