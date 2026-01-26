import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea"]
  static values = {
    draft: String
  }

  apply(event) {
    event.preventDefault()
    if (!this.hasTextareaTarget || !this.hasDraftValue) return

    // Find the actual textarea element within the target wrapper
    const textarea = this.textareaTarget.querySelector("textarea")
    if (!textarea) return

    textarea.value = this.draftValue
    textarea.dispatchEvent(new Event("input", {bubbles: true}))

    // Hide the apply button after applying
    event.currentTarget.closest("[data-draft-container]")?.remove()
  }
}
