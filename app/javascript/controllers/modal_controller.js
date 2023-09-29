import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open(event) {
    event.preventDefault();

    this.modalTarget.showModal();

    this.modalTarget.addEventListener('click', (e) =>  this.backdropClick(e));
  }

  backdropClick(event) {
    event.target === this.modalTarget && this.close(event)
  }

  close(event) {
    event.preventDefault();

    this.modalTarget.close();
  }
}
