import {Controller} from "@hotwired/stimulus"

// Generic controller to apply text content to a textarea
// Usage:
//   <div data-controller="text-applier" data-text-applier-content-value="text to apply">
//     <div data-text-applier-target="container">
//       <button data-action="click->text-applier#apply">Apply</button>
//     </div>
//     <div data-text-applier-target="input">
//       <textarea>...</textarea>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["input", "container"]
  static values = {
    content: String
  }

  apply(event) {
    event.preventDefault()
    if (!this.hasInputTarget || !this.hasContentValue) return

    const textarea = this.inputTarget.querySelector("textarea")
    if (!textarea) return

    textarea.value = this.contentValue
    textarea.dispatchEvent(new Event("input", {bubbles: true}))

    if (this.hasContainerTarget) {
      this.containerTarget.remove()
    }
  }
}
