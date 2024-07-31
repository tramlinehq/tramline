import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "source", "success"]
  
  connect() {
    if (!this.hasButtonTarget) return
    this.hidden = this.sourceTarget.type === "password"
    this.originalButton = this.buttonTarget.innerHTML
  }

  toggle(event) {
    event.preventDefault()

    if (this.hidden) {
      this.sourceTarget.type = "text"
      this.buttonTarget.innerHTML = this.successTarget.innerHTML
    } else {
      this.sourceTarget.type = "password"
      this.buttonTarget.innerHTML = this.originalButton
    }

    this.hidden = !this.hidden
  }
}
