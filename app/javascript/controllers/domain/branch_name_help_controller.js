import {Controller} from "@hotwired/stimulus";
import strftime from "strftime";

const baseHelpText = "The release branch will follow the pattern of:"

export default class extends Controller {
  static targets = [
    "input",
    "helpTextTitle",
    "helpTextVal"
  ]

  connect() {
    this.updatePreview();
  }

  updatePreview() {
    const patternValue = this.inputTarget.value.trim();

    if (patternValue.length === 0) {
      this.helpTextTitleTarget.innerHTML = ""
      this.helpTextValTarget.innerHTML = ""
      return;
    }

    this.helpTextTitleTarget.innerHTML = baseHelpText
    this.helpTextValTarget.innerHTML = this.interpolateTokens(patternValue);
  }

  interpolateTokens(pattern) {
    if (!pattern) return "";

    const exampleValues = {
      trainName: "my-train",
      releaseVersion: "1.2.3",
      releaseStartDate: strftime('%Y-%m-%d')
    };

    let result = pattern;

    // replace placeholders
    Object.entries(exampleValues).forEach(([token, value]) => {
      const tokenPattern = new RegExp(`~${token}~`, 'g');
      result = result.replace(tokenPattern, value);
    });

    return result;
  }
}
