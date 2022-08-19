import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ['branching-selector']

  initialize() {
    const class_name = document.querySelector('[name="releases_train[branching_strategy]"]').value
    for (let el of document.querySelectorAll("." + class_name)) el.classList.remove("hidden");
  }

  change(event) {
    this.resetFields();
    const class_name = event.srcElement.value
    for (let el of document.querySelectorAll("." + class_name)) el.classList.remove("hidden");
  }

  resetFields() {
    ['.almost_trunk', '.release_backmerge', '.parallel_working'].forEach(selector => {
      for (let el of document.querySelectorAll(selector)) el.classList.add("hidden");
    });
  }
}

