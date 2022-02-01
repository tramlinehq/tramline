import { Controller } from "@hotwired/stimulus";
import SlimSelect from "slim-select";

export default class extends Controller {
  static values = {
    options: Object
  };

  connect() {
    this.slimselect = new SlimSelect({
      select: this.element,
      addable: (value) => value,
    });
  }

  disconnect() {
    this.slimselect.destroy();
  }
}