import {Controller} from "@hotwired/stimulus";
import { get } from "@rails/request.js"

export default class extends Controller {
  static values = { train: String, app: String, step: String }

  initialize() {
    this.train = this.element.dataset.train
    this.app = this.element.dataset.app
    this.step = this.element.dataset.step
	}

  change(event) {
	  let selected = event.target.selectedOptions[0].value

	  get(`/apps/${this.app}/trains/${this.train}/steps/build_artifact_channels?provider=${selected}&step_id=${this.step}`, {
      responseKind: "turbo-stream"
	  })
	}
}
