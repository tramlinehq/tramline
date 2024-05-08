import {Controller} from "@hotwired/stimulus"
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = { url: String, param: String }
  static targets = ["dispatch"]

  connect() {
    this.dispatchTarget.disabled = false;
  }

  fetch() {
    const url = new URL(this.urlValue);
    this.hasParamValue && url.searchParams.set(this.paramValue, this.dispatchTarget.value);
    get(url, {responseKind: "turbo-stream"});
  }
}
