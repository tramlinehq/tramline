import {Controller} from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static values = {
    options: Object
  };

  connect() {
    this.select = new TomSelect(this.element, {
      maxOptions: 5,
      addPrecedence: true,
      diacritics: true,
      onItemAdd: function () {
        this.setTextboxValue('');
      },
      ...this.optionsValue,
    });
  }

  disconnect() {
    if (this.select) {
      this.select.destroy();
    }
  }

  sync() {
    if (this.select) {
      this.select.sync();
    }
  }
}
