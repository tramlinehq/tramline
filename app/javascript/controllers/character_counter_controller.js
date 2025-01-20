import { Controller } from "@hotwired/stimulus"

const ERROR_CLASS = "text-rose-700"

export default class extends Controller {
  static targets = ["input", "counter"]
  static values = {
    maxLength: {type: Number, default: 500},
  }

  connect() {
    this.update()
  }

  update() {
    let value = this.inputTarget.value.length

    if (value > this.maxLengthValue) {
      this.counterTarget.classList.add(ERROR_CLASS)
    } else {
      this.counterTarget.classList.remove(ERROR_CLASS)
    }

    this.counterTarget.innerHTML = value
  }
}
