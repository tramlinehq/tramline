import Sortable from "stimulus-sortable"

export default class extends Sortable {
  static outlets = ["list-position"]

  get defaultOptions() {
    return {
      ...super.defaultOptions,
      forceFallback: false,
      removeCloneOnHide: true,
      easing: "cubic-bezier(1, 0, 0, 1)",
      animation: 300
    }
  }

  onUpdate(event) {
    super.onUpdate(event)
    this.updatePositions()
  }

  updatePositions() {
    if (this.hasListPositionOutlet) {
      this.listPositionOutlet.update()
    }
  }
}
