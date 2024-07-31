# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "flatpickr", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/flatpickr.js"
pin "stimulus-flatpickr", to: "https://ga.jspm.io/npm:stimulus-flatpickr@3.0.0-0/dist/index.m.js"
pin "slim-select", to: "https://ga.jspm.io/npm:slim-select@1.27.1/dist/slimselect.min.mjs"
pin "stimulus-reveal", to: "https://ga.jspm.io/npm:stimulus-reveal@1.4.2/dist/stimulus-reveal.esm.js"
pin "semver-increment", to: "https://ga.jspm.io/npm:semver-increment@1.0.1/index.js"
pin "fs", to: "https://ga.jspm.io/npm:@jspm/core@2.0.0-beta.27/nodelibs/browser/fs.js"
pin "semver-utils", to: "https://ga.jspm.io/npm:semver-utils@1.1.1/semver-utils.js"
pin "parameterize-string", to: "https://ga.jspm.io/npm:parameterize-string@1.0.1/lib/index.js"
pin "strftime", to: "https://ga.jspm.io/npm:strftime@0.10.1/strftime.js"
pin "stimulus-sortable", to: "https://ga.jspm.io/npm:stimulus-sortable@4.1.0/dist/stimulus-sortable.mjs"
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.8/src/index.js"
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.0/modular/sortable.esm.js"
pin "stimulus-rails-nested-form", to: "https://ga.jspm.io/npm:stimulus-rails-nested-form@4.1.0/dist/stimulus-rails-nested-form.mjs"
pin "stimulus-use", to: "https://ga.jspm.io/npm:stimulus-use@0.51.3/dist/index.js"
pin "hotkeys-js", to: "https://ga.jspm.io/npm:hotkeys-js@3.10.1/dist/hotkeys.esm.js"
pin "stimulus-confetti", to: "https://ga.jspm.io/npm:stimulus-confetti@1.0.1/dist/stimulus_confetti.modern.js"
pin "canvas-confetti", to: "https://ga.jspm.io/npm:canvas-confetti@1.6.0/dist/confetti.module.mjs"
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@4.0.4/dist/tailwindcss-stimulus-components.module.js"
pin "@sentry/browser", to: "https://ga.jspm.io/npm:@sentry/browser@7.69.0/esm/index.js"
pin "@sentry-internal/tracing", to: "https://ga.jspm.io/npm:@sentry-internal/tracing@7.69.0/esm/index.js"
pin "@sentry/core", to: "https://ga.jspm.io/npm:@sentry/core@7.69.0/esm/index.js"
pin "@sentry/replay", to: "https://ga.jspm.io/npm:@sentry/replay@7.69.0/esm/index.js"
pin "@sentry/utils", to: "https://ga.jspm.io/npm:@sentry/utils@7.69.0/esm/index.js"
pin "@sentry/utils/esm/buildPolyfills", to: "https://ga.jspm.io/npm:@sentry/utils@7.69.0/esm/buildPolyfills/index.js"
pin "apexcharts", to: "https://ga.jspm.io/npm:apexcharts@3.43.0/dist/apexcharts.common.js"
pin "humanize-duration", to: "https://ga.jspm.io/npm:humanize-duration@3.30.0/humanize-duration.js"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
pin "quill", to: "https://ga.jspm.io/npm:quill@2.0.0/quill.js"
pin "eventemitter3", to: "https://ga.jspm.io/npm:eventemitter3@5.0.1/index.mjs"
pin "fast-diff", to: "https://ga.jspm.io/npm:fast-diff@1.3.0/diff.js"
pin "lodash-es", to: "https://ga.jspm.io/npm:lodash-es@4.17.21/lodash.js"
pin "lodash.clonedeep", to: "https://ga.jspm.io/npm:lodash.clonedeep@4.5.0/index.js"
pin "lodash.isequal", to: "https://ga.jspm.io/npm:lodash.isequal@4.5.0/index.js"
pin "parchment", to: "https://ga.jspm.io/npm:parchment@3.0.0/dist/parchment.js"
pin "quill-delta", to: "https://ga.jspm.io/npm:quill-delta@5.1.0/dist/Delta.js"
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js"
