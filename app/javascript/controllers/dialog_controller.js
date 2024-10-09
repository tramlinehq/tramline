import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    dismissable: Boolean,
    open: {
      type: Boolean,
      default: false
    }
  }

  connect() {
    if (this.openValue) {
      this.open(null)
    }
  }

  open(event) {
    if (event) {
      event.preventDefault();
    }

    this.dialogTarget.showModal(); // Show the dialog

    /* Remove focus from the dialog */
    this.dialogTarget.focus();
    this.dialogTarget.blur();

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
