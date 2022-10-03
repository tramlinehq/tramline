import {Controller} from "@hotwired/stimulus";
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {train: String, app: String, step: String}
  static targets = ["channels"]

  initialize() {
    this.train = this.element.dataset.train
    this.app = this.element.dataset.app
    this.step = this.element.dataset.step
    this.deploymentNumber = this.element.dataset.deploymentNumber
  }

  updateExternalChannels() {
    this.channelsTarget.innerHTML = ""
    const option = document.createElement("option")
    option.value = '{"external": "external"}'
    option.innerHTML = "External"
    this.channelsTarget.appendChild(option)
  }

  change(event) {
    const integrationID = event.target.selectedOptions[0].value

    if (integrationID === "") {
      this.updateExternalChannels()
      return
    }

    get(`/apps/${this.app}/integrations/${integrationID}/build_artifact_channels?deployment_number=${this.deploymentNumber}`, {responseKind: "turbo-stream"})
  }
}
