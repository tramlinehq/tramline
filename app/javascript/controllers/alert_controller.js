import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["alert"]

  close() {
    this.alertTarget.remove()
    return false
  }
}
