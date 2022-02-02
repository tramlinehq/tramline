// Import and register all your controllers from the importmap under controllers/*

import { application } from 'controllers/application'

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading'

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)

// import Flatpickr
import Flatpickr from 'stimulus-flatpickr'

// import InputSelect
import InputSelect from './input_select'
eagerLoadControllersFrom('controllers', application)
application.register('flatpickr', Flatpickr)
application.register('inputselect', InputSelect)
