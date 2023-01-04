import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static outlets = ["visibility"]

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.hasVisibilityOutlet) {
      this.visibilityOutlet.toggle()
    }
  }
}
