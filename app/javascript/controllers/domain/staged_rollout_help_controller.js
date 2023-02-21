import {Controller} from "@hotwired/stimulus";

const baseHelpText = "You will be able to rollout to users in the following stages: "

export default class extends Controller {
  static targets = [
    "input",
    "helpErrorText",
    "helpSuccessText",
  ]

  initialize() {
    this.stages = [];
  }

  clear() {
    this.helpErrorTextTarget.innerHTML = ""
    this.helpSuccessTextTarget.innerHTML = ""
  }

  validateString() {
    if (!this.hasHelpErrorTextTarget && !this.hasHelpSuccessTextTarget) {
      return
    }

    const arr = this.__cleanupInput(this.inputTarget.value)

    // when only 1 value is present without commas
    if (arr.length === 1) {
      if (isNaN(arr[0])) {
        this.__setError("All items in the rollout list should be numbers!")
        return
      }

      if (arr[0] > 100) {
        this.__setError("Rollouts cannot be more than 100%")
        return
      }

      if (isNaN(arr[0]) || +arr[0] <= 0) {
        this.__setError("The first rollout must be more than zero!")
        return
      }
    } else { // when comma separated
      if (isNaN(arr[0]) || +arr[0] <= 0) {
        this.__setError("The first rollout must be more than zero!")
        return
      }

      // an item is not a number or it's not monotonically increasing
      let prev = +arr[0];
      for (let i = 1; i < arr.length; i++) {
        if (isNaN(arr[i]) || +arr[i] <= prev) {
          this.__setError("All items in the rollout list must be numbers in increasing order!")
          return
        }

        if (arr[i] > 100) {
          this.__setError("Rollouts cannot be more than 100%")
          return
        }

        prev = +arr[i];
      }
    }

    this.stages = arr;
    return this.__setSuccess();
  }

  __setError(errStr) {
    this.helpErrorTextTarget.innerHTML = errStr;
  }

  __setSuccess() {
    this.__setError("");
    this.helpSuccessTextTarget.innerHTML = baseHelpText + this.__addPercentages(this.stages);
  }

  __addPercentages(numbers) {
    const percentageNumbers = numbers.map((number) => `${number}%`);
    return percentageNumbers.join(", ");
  }

  __cleanupInput(str) {
    return str.split(",").map(item => item.trim()).filter(item => item);
  }
}
