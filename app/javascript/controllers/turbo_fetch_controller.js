import {Controller} from "@hotwired/stimulus";
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {
    url: String,
    targetKey: String
  }

  static targets = ["select"]

  change(event) {
    const integrationID = event.target.selectedOptions[0].value
    const url = new URL(this.urlValue)
    url.searchParams.set(this.targetKeyValue, integrationID);
    url.searchParams.set('target', this.selectTarget.id);
    get(url, {responseKind: "turbo-stream"})
  }
}
