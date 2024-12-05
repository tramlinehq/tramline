import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["freezeReleaseVersion", "patchVersionBumpOnly"]

  initialize() {
    this.updatePatchVersionBumpState()
  }

  change() {
    this.updatePatchVersionBumpState()
  }

  updatePatchVersionBumpState() {
    this.patchVersionBumpOnlyTarget.disabled = this.freezeReleaseVersionTarget.checked;
  }
}
