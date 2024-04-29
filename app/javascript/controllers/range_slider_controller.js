import {Controller} from "@hotwired/stimulus";

export default class extends Controller {

  static targets = ["fromSlider", "toSlider", "fromInput", "toInput"]

  static values = {
    belowRangeColor: {type: String, default: "#fda4af"},
    midRangeColor: {type: String, default: "#7dd3fc"},
    aboveRangeColor: {type: String, default: "#86efac"}
  }

  connect() {
    const fromSlider = this.fromSliderTarget;
    const toSlider = this.toSliderTarget;
    this.fillSlider(fromSlider, toSlider, toSlider);
  }

  controlFromInput() {
    const fromSlider = this.fromSliderTarget;
    const fromInput = this.fromInputTarget;
    const toInput = this.toInputTarget;
    const controlSlider = this.toSliderTarget;
    const [from, to] = this.getParsed(fromInput, toInput);
    if (from > to) {
      fromSlider.value = to;
      fromInput.value = to;
    } else {
      fromSlider.value = from;
    }
    this.fillSlider(fromInput, toInput, controlSlider);
  }

  controlToInput() {
    const toSlider = this.toSliderTarget;
    const fromInput = this.fromInputTarget;
    const toInput = this.toInputTarget;
    const controlSlider = this.toSliderTarget;
    const [from, to] = this.getParsed(fromInput, toInput);
    if (from <= to) {
      toSlider.value = to;
      toInput.value = to;
    } else {
      toInput.value = from;
    }
    this.fillSlider(fromInput, toInput, controlSlider);
  }

  controlFromSlider() {
    const fromSlider = this.fromSliderTarget;
    const toSlider = this.toSliderTarget;
    const fromInput = this.fromInputTarget;
    const [from, to] = this.getParsed(fromSlider, toSlider);
    if (from > to) {
      fromSlider.value = to;
      fromInput.value = to;
    } else {
      fromInput.value = from;
    }
    this.fillSlider(fromSlider, toSlider, toSlider);
  }

  controlToSlider() {
    const fromSlider = this.fromSliderTarget;
    const toSlider = this.toSliderTarget;
    const toInput = this.toInputTarget;
    const [from, to] = this.getParsed(fromSlider, toSlider);
    if (from <= to) {
      toSlider.value = to;
      toInput.value = to;
    } else {
      toInput.value = from;
      toSlider.value = from;
    }
    this.fillSlider(fromSlider, toSlider, toSlider);
  }

  getParsed(currentFrom, currentTo) {
    const from = Number(currentFrom.value);
    const to = Number(currentTo.value);
    return [from, to];
  }

  fillSlider(from, to, controlSlider) {
    const rangeDistance = to.max - to.min;
    const fromPosition = from.value - to.min;
    const toPosition = to.value - to.min;
    const rangeColor = this.midRangeColorValue;
    const belowRangeColor = this.belowRangeColorValue;
    const aboveRangeColor = this.aboveRangeColorValue;
    controlSlider.style.background = `linear-gradient(
      to right,
      ${belowRangeColor} ${(fromPosition / rangeDistance) * 100}%,
      ${rangeColor} ${(fromPosition / rangeDistance) * 100}% ${(toPosition / rangeDistance) * 100}%,
      ${aboveRangeColor} ${(toPosition / rangeDistance) * 100}%`;
  }
}
