import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  selectApp(event) {
    const radio = event.currentTarget

    try {
      const appData = JSON.parse(radio.value)

      if (!this.hasFormTarget) {
        console.warn("Form target not found for app selector")
        return
      }

      const form = this.formTarget

      // Update hidden fields with app data
      const nameField = form.querySelector('[name*="name"]')
      const bundleIdField = form.querySelector('[name*="bundle_identifier"]')
      const descriptionField = form.querySelector('[name*="description"]')

      if (nameField) nameField.value = appData.name || ""
      if (bundleIdField) bundleIdField.value = appData.bundleId || ""
      if (descriptionField) descriptionField.value = appData.description || ""
    } catch (e) {
      console.error("Failed to parse app data:", e)
    }
  }
}
