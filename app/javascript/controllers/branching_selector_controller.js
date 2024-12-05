import {Controller} from "@hotwired/stimulus";

const STRATEGIES = {
  trunk: "trunk",
  almost_trunk: "almost_trunk",
  release_backmerge: "release_backmerge",
  parallel_working: "parallel_working"
}
export default class extends Controller {
  static targets = ["branchingStrategy", "almostTrunk", "trunk", "releaseBackMerge", "parallelBranches", "backmerge", "buildQueueToggle"]
  static outlets = ["domain--build-queue-help", "domain--release-schedule-help"]

  initialize() {
    this.showCorrectInputs()
  }

  change() {
    this.showCorrectInputs()
    
    if (this.hasDomainBuildQueueHelpOutlet) {
      this.domainBuildQueueHelpOutlet.branchingStrategyValue = this.branchingStrategyTarget.value
    }
  }

  showCorrectInputs() {
    this.__resetFields()
    const selectedBranchingStrategy = this.branchingStrategyTarget.value


    if (selectedBranchingStrategy === STRATEGIES.trunk) {
      this.disableBuildQueueToggle()
      this.__hideBackmergeConfig()
    } else if (selectedBranchingStrategy === STRATEGIES.almost_trunk) {
      this.almostTrunkTarget.hidden = false
      this.enableBuildQueueToggle()
      this.__showBackmergeConfig()
    } else if (selectedBranchingStrategy === STRATEGIES.release_backmerge) {
      this.releaseBackMergeTarget.hidden = false
      this.enableBuildQueueToggle()
      this.__hideBackmergeConfig()
    } else if (selectedBranchingStrategy === STRATEGIES.parallel_working) {
      this.parallelBranchesTarget.hidden = false
      this.enableBuildQueueToggle()
      this.__hideBackmergeConfig()
    }
  }

  __resetFields() {
    this.almostTrunkTarget.hidden = true
    this.releaseBackMergeTarget.hidden = true
    this.parallelBranchesTarget.hidden = true
  }

  __hideBackmergeConfig() {
    this.backmergeTarget.hidden = true
  }

  __showBackmergeConfig() {
    this.backmergeTarget.hidden = false
  }

  disableBuildQueueToggle() {
    this.buildQueueToggleTarget.disabled = true
  }

  enableBuildQueueToggle() {
    this.buildQueueToggleTarget.disabled = false;
  }
}
