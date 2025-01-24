import {ApplicationController, useDebounce} from "stimulus-use"

const MIN_CHARACTERS = 2;
const URL_SEARCH_PATTERN = "search_pattern"

export default class extends ApplicationController {
    static targets = ["form"]
    static debounces = ['search']

    connect() {
        useDebounce(this, {wait: 200})
    }

    search() {
        const queryLength = this.query.value.length

        if (queryLength === 0) {
            this.query.value = ""
        }

        if (queryLength > MIN_CHARACTERS || queryLength === 0) {
            this.formTarget.requestSubmit();
            this.updateURL();
        }
    }

    clear() {
        const queryLength = this.query.value.length

        if (queryLength > 0) {
            this.query.value = ""
        }

        if (queryLength > MIN_CHARACTERS) {
            this.formTarget.requestSubmit();
            this.updateURL();
        }
    }

    updateURL() {
        const searchValue = this.query.value
        const url = new URL(window.location)
        
        if (searchValue) {
            url.searchParams.set(URL_SEARCH_PATTERN, searchValue)
        } else {
            url.searchParams.delete(URL_SEARCH_PATTERN)
        }

        window.history.pushState({}, '', url)
    }

    get query() {
        return this.formTarget.querySelector(`input[name=${URL_SEARCH_PATTERN}]`)
    }


}
