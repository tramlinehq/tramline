import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ['branching-selector']

  initialize() {
    const className = document.querySelector('[name="releases_train[branching_strategy]"]').value
    for (let el of document.querySelectorAll("." + className)) el.classList.remove("hidden")
  }

  change(event) {
    this.__resetFields()
    const className = event.srcElement.value
    for (let el of document.querySelectorAll("." + className)) el.classList.remove("hidden")
  }

  __resetFields() {
    ['.almost_trunk', '.release_backmerge', '.parallel_working'].forEach(selector => {
      for (let el of document.querySelectorAll(selector)) el.classList.add("hidden");
    });
  }
}

