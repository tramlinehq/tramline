import {ApplicationController, useDebounce} from "stimulus-use"

export default class extends ApplicationController {
    static targets = ["form"]
    static debounces = ['search']

    connect() {
        useDebounce(this, {wait: 250})
    }

    search() {
        const query = this.formTarget.querySelector("input[name='query']")
        const queryLength = query.value.length

        if (queryLength > 3 || queryLength === 0) {
            this.formTarget.requestSubmit();
        }
    }
}
