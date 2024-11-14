import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = {
    countDownHours: Number,
    countUpTime: Number,
    direction: {type: String, default: "down"},
    enabled: {type: Boolean, default: true}
  }

  connect() {
    if (this.enabledValue) {
      if (this.directionValue === "down") {
        this.targetTime = new Date().getTime() + this.countDownHoursValue * 60 * 60 * 1000
        this.updateCountDown()
      } else if (this.directionValue === "up") {
        this.targetTime = this.countUpTimeValue
        this.updateCountUp()
      }
    }
  }

  updateCountDown() {
    const currentTime = new Date().getTime()
    const diff = this.targetTime - currentTime

    if (diff > 0) {
      let hours = Math.floor(diff / 1000 / 60 / 60)
      let minutes = Math.floor(diff / 1000 / 60) % 60
      let seconds = Math.floor(diff / 1000) % 60
      hours = hours.toString().padStart(2, '0')
      minutes = minutes.toString().padStart(2, '0')
      seconds = seconds.toString().padStart(2, '0')
      this.outputTarget.textContent = `${hours}:${minutes}:${seconds}`
      setTimeout(() => this.updateCountDown(), 1000)
    } else {
      this.outputTarget.textContent = "00:00:00"
    }
  }

  updateCountUp() {
    const currentTime = new Date().getTime()
    const diff = currentTime - this.targetTime
    let totalSeconds = Math.floor(diff / 1000);
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    minutes = minutes.toString();
    seconds = seconds.toString().padStart(2, '0');
    this.outputTarget.textContent = `${minutes}m ${seconds}s`;
    setTimeout(() => this.updateCountUp(), 1000);
  }
}
