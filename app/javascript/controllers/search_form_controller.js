import {ApplicationController, useDebounce} from "stimulus-use"

const MIN_CHARACTERS = 2;

export default class extends ApplicationController {
  static targets = ["form", "searchInput"]
  static debounces = ['search']
  static values = {query: String}

  connect() {
    useDebounce(this, {wait: 200})

    // Listen for the focus-search event
    this.focusHandler = () => this.focusSearch()
    document.addEventListener('focus-search', this.focusHandler)

    // If we just navigated to the search page, focus the input
    if (window.location.pathname.includes('/search')) {
      this.focusSearch()
    }
  }

  disconnect() {
    document.removeEventListener('focus-search', this.focusHandler)
  }

  focusSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.focus()
      // Optionally select all text in the input
      this.searchInputTarget.select()
    }
  }

  search() {
    let query = this.searchInputTarget
    const queryLength = query.value.length

    if (queryLength === 0) {
      query.value = ""
    }

    // only search if query is greater than MIN_CHARACTERS
    if (queryLength > MIN_CHARACTERS || queryLength === 0) {
      this.__shadowQuery().value = query.value
      this.formTarget.requestSubmit();
    }
  }

  clear() {
    let query = this.searchInputTarget
    const queryLength = query.value.length

    if (queryLength > 0) {
      query.value = ""
    }

    // don't bother running an empty search if it is less than MIN_CHARACTERS
    if (queryLength > MIN_CHARACTERS) {
      this.formTarget.requestSubmit();
    }
  }

  __shadowQuery() {
    return this.formTarget.querySelector(`input[name=${this.queryValue}]`)
  }
}
