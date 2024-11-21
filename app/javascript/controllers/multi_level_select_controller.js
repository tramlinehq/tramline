import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];
  static values = {options: Object}; // The hierarchical data structure
  static outlets = ["input-select"]

  connect() {
    this.populateDropdown(this.selectTargets[0], this.optionsValue[this.selectTargets[0].dataset.level], true);
    this.updateNextOptions(this.selectTargets[0], true);
  }

  update(event) {
    this.updateNextOptions(event.target, false);
  }

  updateNextOptions(currentSelect, selected) {
    const targetLevel = currentSelect.dataset.targetLevel;
    const matchingTargetSelect = this.selectTargets.find(select => select.dataset.level === targetLevel);
    if (!matchingTargetSelect) return;
    let nextOptions = this.optionsValue;

    const currentLevelIndex = this.selectTargets.indexOf(currentSelect);
    for (let nodeIndex = 0; nodeIndex <= currentLevelIndex; nodeIndex++) {
      const nodeSelect = this.selectTargets[nodeIndex];
      const nodeLevel = nodeSelect.dataset.level;
      const nodeKey = nodeSelect.dataset.levelKey;
      const nodeValue = this.__safeJSONParse(nodeSelect.value);

      nextOptions = nextOptions[nodeLevel].find(o => o[nodeKey] === nodeValue);
    }

    this.populateDropdown(matchingTargetSelect, nextOptions[targetLevel], selected);
    this.updateNextOptions(matchingTargetSelect, selected);
  }

  populateDropdown(target, options, selected) {
    const valueKey = target.dataset.levelKey
    const displayKey = target.dataset.levelDisplayKey
    let selectedValue;
    if (selected) selectedValue = target.dataset.selectedValue

    this.__refreshInputSelectOutlet(target.id, true)
    target.innerHTML = options.map((option, i) => this.__createOption(option, valueKey, displayKey, selectedValue, i)).join("");
    target.disabled = options.length === 0; // Disable if no options available
    this.__refreshInputSelectOutlet(target.id, false)
  }

  __createOption(option, valueKey, displayKey, selectedValue, optionIndex) {
    const optionValue = option[valueKey];
    const optionName = option[displayKey];
    let selected = ""

    // if there's no selected value, pick the first one
    if ((!selectedValue || selectedValue === "") && optionIndex === 0) {
      selected = "selected"
    }

    // assign selected option
    if (selectedValue && selectedValue !== "" && selectedValue === optionValue) {
      selected = "selected"
    }

    return `<option value=${JSON.stringify(optionValue)} ${selected}>${optionName}</option>`;
  }

  __safeJSONParse(str) {
    let parsedJSON = null;

    try {
      parsedJSON = JSON.parse(str);
    } catch (e) {
      return str;
    }

    return parsedJSON;
  }

  // when the outlet gets force-updated
  __refreshInputSelectOutlet(selectId, clearSelected) {
    if (this.hasInputSelectOutlet && this.inputSelectOutlets.length > 0) {
      let selectedOutlet = this.inputSelectOutlets.find(outlet => outlet.element.getAttribute("id") === selectId);
      if (selectedOutlet) {
        selectedOutlet.sync(clearSelected);
      }
    }
  }

  // when the outlet first gets connected
  inputSelectOutletConnected(outlet, _) {
    outlet.sync(false)
  }
}
