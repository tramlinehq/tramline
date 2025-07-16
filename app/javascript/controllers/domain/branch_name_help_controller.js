import {Controller} from "@hotwired/stimulus";
import parameterize from "parameterize-string";
import strftime from "strftime";

const baseHelpText = "The release branch will follow the pattern of:"

export default class extends Controller {
  static values = {
    current: String,
    pattern: String,
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
    const pattern = this.patternValue || "r/{{train_name}}/%Y-%m-%d";
    const displayName = parameterize(value);
    
    // Replace the placeholders with example values
    let branchName = pattern.replace(/\{\{train_name\}\}/g, displayName);
    branchName = branchName.replace(/\{\{version_number\}\}/g, "1.2.3");
    branchName = branchName.replace(/\{\{build_number\}\}/g, "42");
    
    // Replace strftime patterns with actual formatted date
    branchName = branchName.replace(/%Y/g, strftime('%Y'));
    branchName = branchName.replace(/%m/g, strftime('%m'));
    branchName = branchName.replace(/%d/g, strftime('%d'));
    branchName = branchName.replace(/%H/g, strftime('%H'));
    branchName = branchName.replace(/%M/g, strftime('%M'));
    branchName = branchName.replace(/%S/g, strftime('%S'));
    
    return branchName;
  }
}
