import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    dismissable: Boolean,
  }

  open(event) {
    event.preventDefault();
    this.dialogTarget.showModal();
    if (this.dismissableValue) {
      this.dialogTarget.addEventListener('click', (e) => this.backdropClick(e));
    }
  }

  backdropClick(event) {
    event.target === this.dialogTarget && this.close(event)
  }

  close(event) {
    event.preventDefault();
    this.dialogTarget.close();
  }
}
