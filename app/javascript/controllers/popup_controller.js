// this controller can be used for dropdowns, tooltips, and popovers
// it wraps stimulus-reveal + popper.js
import {createPopper} from "@popperjs/core"
import RevealController from "stimulus-reveal"

export default class extends RevealController {
  static targets = ["element"];

  static values = {
    placement: {type: String, default: "bottom"},
    offset: {type: Array, default: [0, 7]}
  };

  connect() {
    super.connect()
    this.popperInstance = createPopper(this.elementTarget, this.popoverSelector, {
      placement: this.placementValue,
      modifiers: [
        {
          name: "offset",
          options: {
            offset: this.offsetValue,
          },
        },
      ],
    });
  }

  toggle(event) {
    super.toggle(event)
    this.popperInstance.update()
  }

  show(event) {
    super.show(event)
    this.popperInstance.update()
  }

  hide(event) {
    super.hide(event)
    this.popperInstance.update()
  }

  disconnect() {
    super.disconnect()
    if (this.popperInstance) {
      this.popperInstance.destroy()
    }
  }

  // popover only works for one target
  get popoverSelector() {
    return this.element.querySelector(this.selector)
  }
}
