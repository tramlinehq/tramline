import { Controller } from "@hotwired/stimulus"
import hotkeys from "hotkeys-js"

export default class extends Controller {
  connect() {
    hotkeys('/', (event) => {
      event.preventDefault()
      const appId = document.querySelector('meta[name="currentAppId"]')?.content

      if (appId) {
        if (window.location.pathname.includes(`/apps/${appId}/search`)) {
          document.dispatchEvent(new CustomEvent('focus-search'))
        } else {
          window.location.href = `/apps/${appId}/search`
        }
      }
    })
  }

  disconnect() {
    hotkeys.unbind('/')
  }
}
