import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["freezeReleaseVersion", "patchVersionBumpOnly"]
  static outlets = ["domain--version-name-help"];

  initialize() {
    this.updatePatchVersionBumpState()
    this.updateNextReleaseVersion()
  }

  change() {
    this.updatePatchVersionBumpState()
    this.updateNextReleaseVersion()
  }

  updatePatchVersionBumpState() {
    this.patchVersionBumpOnlyTarget.disabled = this.freezeReleaseVersionTarget.checked;
  }

  updateNextReleaseVersion() {
    if (this.hasDomainVersionNameHelpOutlet) {
      const versionNameHelpController = this.domainVersionNameHelpOutlet;
      if (this.freezeReleaseVersionTarget.checked) {
        versionNameHelpController.nextVersionTarget.innerHTML = versionNameHelpController.__versionString();
      } else {
        versionNameHelpController.nextVersionTarget.innerHTML = versionNameHelpController.__nextReleaseVersion();
      }
    }
  }
}
