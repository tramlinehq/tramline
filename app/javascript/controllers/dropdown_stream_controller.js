import {Controller} from "@hotwired/stimulus";
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {
    url: String,
    targetKey: String
  }

  static targets = ["select"]

  change(event) {
    const targetKeyId = event.target.selectedOptions[0].value
    let url = new URL(this.urlValue)
    url.searchParams.set(this.targetKeyValue, targetKeyId);
    url.searchParams.set('target', this.selectTarget.id);

    get(url, {responseKind: "turbo-stream"})
  }
}
