import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static outlets = ["visibility"]

  update(event) {
    event.preventDefault()
    event.stopPropagation()
    console.log("I stole this temporarily!");
    console.log(this.visiblityOutlet)
    console.log(this.visiblityOutlets)
  }
}
