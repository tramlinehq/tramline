import {ApplicationController, useDebounce} from "stimulus-use"

const MIN_CHARACTERS = 3;

export default class extends ApplicationController {
    static targets = ["form"]
    static debounces = ['search']

    connect() {
        useDebounce(this, {wait: 250})
    }

    search() {
        const queryLength = this.query.value.length

        if (queryLength > MIN_CHARACTERS || queryLength === 0) {
            this.formTarget.requestSubmit();
        }
    }

    clear() {
        const queryLength = this.query.value.length

        if (queryLength > 0) {
            this.query.value = ""
        }

        if (queryLength > MIN_CHARACTERS) {
            this.formTarget.requestSubmit();
        }
    }

    get query() {
        return this.formTarget.querySelector("input[name='search_pattern']")
    }
}
