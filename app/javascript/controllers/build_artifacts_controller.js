import {Controller} from "@hotwired/stimulus";
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {
    app: String,
  }

  static targets = ["select"]

  initialize() {
    this.app = this.element.dataset.app
  }

  updateExternalChannels() {
    this.selectTarget.innerHTML = ""
    const option = document.createElement("option")
    option.value = '{"external": "external"}'
    option.innerHTML = "External"
    this.selectTarget.appendChild(option)
  }

  change(event) {
    const integrationID = event.target.selectedOptions[0].value

    if (integrationID === "") {
      this.updateExternalChannels()
      return
    }

    get(`/apps/${this.app}/integrations/${integrationID}/build_artifact_channels?target=${this.selectTarget.id}`, {
      responseKind: "turbo-stream"
    })
  }
}
