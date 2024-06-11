import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = {hours: Number}

  connect() {
    this.targetTime = new Date().getTime() + this.hoursValue * 60 * 60 * 1000
    this.updateCountdown()
  }

  updateCountdown() {
    const diff = this.targetTime - new Date().getTime()

    if (diff > 0) {
      let hours = Math.floor(diff / 1000 / 60 / 60)
      let minutes = Math.floor(diff / 1000 / 60) % 60
      let seconds = Math.floor(diff / 1000) % 60
      hours = hours.toString().padStart(2, '0')
      minutes = minutes.toString().padStart(2, '0')
      seconds = seconds.toString().padStart(2, '0')
      this.outputTarget.textContent = `${hours}:${minutes}:${seconds}`
      setTimeout(() => this.updateCountdown(), 1000)
    } else {
      this.outputTarget.textContent = "00:00:00"
    }
  }
}
