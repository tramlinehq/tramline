import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "source", "success"]
  static values = {
    successDuration: {
      type: Number,
      default: 1000
    }
  }

  connect() {
    if (!this.hasButtonTarget) return
    this.originalContent = this.buttonTarget.innerHTML
  }

  copy(event) {
    event.preventDefault()
    const text = this.sourceTarget.innerHTML || this.sourceTarget.value
    navigator.clipboard.writeText(text).then(() => this.copied())
  }

  copied() {
    if (!this.hasButtonTarget) return

    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.buttonTarget.innerHTML = this.successTarget.innerHTML
    this.timeout = setTimeout(() => {
      this.buttonTarget.innerHTML = this.originalContent
    }, this.successDurationValue)
  }
}
