import {ApplicationController, useDebounce} from "stimulus-use"

const MIN_CHARACTERS = 2;

export default class extends ApplicationController {
  static targets = ["form", "searchInput"]
  static debounces = ['search']
  static values = {query: String}

  connect() {
    useDebounce(this, {wait: 200})
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
      this.__shadowQuery().value = ""
      query.value = ""
      this.formTarget.requestSubmit() // clear the search results
    }
  }

  __shadowQuery() {
    return this.formTarget.querySelector(`input[name=${this.queryValue}]`)
  }
}
