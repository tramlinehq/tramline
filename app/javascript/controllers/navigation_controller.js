import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  back(event) {
    history.back()
    event.preventDefault()
  }
}
