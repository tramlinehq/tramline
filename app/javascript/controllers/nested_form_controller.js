import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ["addItem", "template"]

  addAssociation(event) {
    event.preventDefault()
    var content = this.templateTarget.innerHTML.replace(/TEMPLATE_RECORD/g, new Date().valueOf())
    this.addItemTarget.insertAdjacentHTML("beforebegin", content)
  }
}
