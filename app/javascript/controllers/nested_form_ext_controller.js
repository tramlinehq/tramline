import NestedForm from "stimulus-rails-nested-form"

export default class extends NestedForm {
  static outlets = ["list-position"]

  add(e) {
    super.add(e)
    this.updatePositions()
  }

  remove(e) {
    super.remove(e)
    this.updatePositions()
  }

  updatePositions() {
    if (this.hasListPositionOutlet) {
      this.listPositionOutlet.update()
    }
  }
}
