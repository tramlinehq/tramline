import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["addItem", "template", "form"]

  initialize() {
    this.insertContent()
  }

  addAssociation(e) {
    e.preventDefault()
    this.insertContent()
  }

  insertContent() {
    const content = this.templateTarget.innerHTML.replace(/TEMPLATE_RECORD/g, new Date().valueOf())
    this.addItemTarget.insertAdjacentHTML("beforebegin", content)
  }
}
