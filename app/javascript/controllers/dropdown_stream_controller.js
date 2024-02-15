import {Controller} from "@hotwired/stimulus";
import {useMutation} from "stimulus-use"
import {get} from "@rails/request.js"

export default class extends Controller {
  static values = {
    dynamicSelectUrl: String,
    dynamicSelectKey: String,
    showElementIf: String,
  }
  static targets = ["dynamicSelect", "showElement", "hideElement"]

  connect() {
    useMutation(this, {childList: true, subtree: true, element: this.dynamicSelectTarget})
    this.showElementOnDynamicSelectChange()
  }

  mutate() {
    this.showElementOnDynamicSelectChange()
  }

  fetchDynamicSelect(event) {
    let url = new URL(this.dynamicSelectUrlValue)
    url.searchParams.set(this.dynamicSelectKeyValue, event.target.selectedOptions[0].value);
    url.searchParams.set('target', this.dynamicSelectTarget.id);

    get(url, {responseKind: "turbo-stream"})
  }

  showElementOnDynamicSelectChange() {
    const selectedShowElementValue = this.dynamicSelectTarget.selectedOptions[0].value

    if (this.showingElementAllowed()) {
      const parsedSelected = this.__safeJSONParse(selectedShowElementValue)
      const parsedMatchers = this.__safeJSONParse(this.showElementIfValue)

      if (parsedSelected && parsedMatchers) {
        this.showElementTarget.hidden = !this.__is_any(parsedSelected, parsedMatchers)
      } else {
        this.showElementTarget.hidden = selectedShowElementValue !== this.showElementIfValue
      }

      if (this.hasHideElementTarget) this.hideElementTarget.hidden = !this.showElementTarget.hidden
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
