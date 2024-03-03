// this controller can be used for dropdowns, tooltips, and popovers
// it wraps stimulus-reveal (for showing and hiding) + popper.js (for positioning)
import {createPopper} from "@popperjs/core"
import RevealController from "stimulus-reveal"

export default class extends RevealController {
  static targets = ["element", "popupArrow"];

  static values = {
    placement: {type: String, default: "bottom"},
    offset: {type: Array, default: [0, 10]}
  };

  connect() {
    super.connect()

    let modifiers = [
      {
        name: "offset",
        options: {
          offset: this.offsetValue,
        },
      },
    ]

    if (this.hasPopupArrowTarget) {
      modifiers.push({
        name: "arrow",
        options: {
          element: this.popupArrowTarget,
        },
      })
    }

    this.popperInstance = createPopper(this.elementTarget, this.popoverSelector(), {
      placement: this.placementValue,
      modifiers: modifiers,
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

  disconnect(event) {
    super.hide(event)
    super.disconnect()
    if (this.popperInstance) {
      this.popperInstance.destroy()
    }
  }

  // popover only works for one target
  popoverSelector() {
    return this.element.querySelector(this.selector)
  }
}
