import {Controller} from "@hotwired/stimulus";
import parameterize from "parameterize-string";
import strftime from "strftime";

const baseHelpText = "The release branch will follow the pattern of:"

export default class extends Controller {
  static values = {
    current: String,
  }

  static targets = [
    "input",
    "helpTextTitle",
    "helpTextVal"
  ]

  initialize() {
    this.__set(this.currentValue);
  }

  set() {
    this.__set(this.inputTarget.value);
  }

  __set(value) {
    if (value.length === 0) {
      this.helpTextTitleTarget.innerHTML = ""
      this.helpTextValTarget.innerHTML = ""
      return;
    }

    this.helpTextTitleTarget.innerHTML = baseHelpText
    this.helpTextValTarget.innerHTML = this.__release_branch_name(value);
  }

  __release_branch_name(value) {
    return "r/" + parameterize(value) + "/" + strftime('%Y-%m-%d');
  }
}
