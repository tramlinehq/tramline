import {Controller} from "@hotwired/stimulus";
import {useMutation} from "stimulus-use"
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {
    url: String,
    targetKey: String,
    showElementIf: String,
  }
  static targets = ["select", "showElement"]

  connect() {
    useMutation(this, {  childList: true, subtree: true, element: this.selectTarget })
    this.toggleElement()
  }

  mutate() {
    this.toggleElement()
  }

  change(event) { // FIXME: change this name
    const targetKeyId = event.target.selectedOptions[0].value

    let url = new URL(this.urlValue)
    url.searchParams.set(this.targetKeyValue, targetKeyId);
    url.searchParams.set('target', this.selectTarget.id);

    get(url, {responseKind: "turbo-stream"})
  }

  toggleElement() {
    const selectedShowElementValue = this.selectTarget.selectedOptions[0].value

    if (this.showingElementAllowed()) {
      const parsedSelected = this.__safeJSONParse(selectedShowElementValue)
      const parsedMatchers = this.__safeJSONParse(this.showElementIfValue)

      if (parsedSelected && parsedMatchers) {
        if (this.__is_any(parsedSelected, parsedMatchers)) {
          this.showElementTarget.style.display = "block"
        } else {
          this.showElementTarget.style.display = "none"
        }
      } else {
        if (selectedShowElementValue === this.showElementIfValue) {
          this.showElementTarget.style.display = "block"
        } else {
          this.showElementTarget.style.display = "none"
        }
      }
    }
  }

  showingElementAllowed() {
    return this.hasShowElementIfValue && this.hasShowElementTarget
  }

  __is_any(obj, matcher) {
    let flag = false;

    for (const [key, value] of Object.entries(matcher)) {
      if (this.__hasKeySetTo(obj, key, value)) {
        flag = true
      }
    }

    return flag;
  }

  __hasKeySetTo(obj, k, v) {
    return obj.hasOwnProperty(k) && obj[k] === v;
  }

  __safeJSONParse(str) {
    let parsedJSON = null;

    try {
      parsedJSON = JSON.parse(str);
    } catch (e) {
      return false;
    }

    return parsedJSON;
  }
}
