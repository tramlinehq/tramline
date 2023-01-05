import Sortable from "stimulus-sortable"

export default class extends Sortable {
  static outlets = ["list-position"]

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
