import {Controller} from "@hotwired/stimulus";
import Rails from "@rails/ujs"

export default class extends Controller {
  static targets = ["submit"]
  static values = { comparison: String }

  onPostSuccess(event) {
    console.log("success!");
  }

  update() {
    console.log("I stole this temporarily!");
    console.log(this.comparisonValue);
    Rails.fire(this.element, 'submit');
  }
}
