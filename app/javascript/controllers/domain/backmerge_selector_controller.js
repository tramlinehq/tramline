import {Controller} from "@hotwired/stimulus";

const BACKMERGE_STRATEGIES = {
  continuous: "continuous",
  on_finalize: "on_finalize",
  disabled: "disabled"
}

export default class extends Controller {
  static targets = ["backmergeStrategy", "continuousOptions"]

  initialize() {
    this.showBackmergeOptions()
  }

  change() {
    this.showBackmergeOptions()
  }

  showBackmergeOptions() {
    if (!this.hasBackmergeStrategyTarget || !this.hasContinuousOptionsTarget) {
      return
    }

    this.__resetFields()
    const selectedBackmergeStrategy = this.backmergeStrategyTarget.value

    if (selectedBackmergeStrategy === BACKMERGE_STRATEGIES.continuous) {
      this.continuousOptionsTarget.hidden = false
    }
  }

  __resetFields() {
    if (this.hasContinuousOptionsTarget) {
      this.continuousOptionsTarget.hidden = true
    }
  }
}