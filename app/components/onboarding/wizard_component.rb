module Onboarding
  class WizardComponent < ViewComponent::Base
    STEPS = {
      vcs_provider: {title: "Version Control Provider", description: "Select your preferred version control provider."},
      connect_vcs_provider: {title: "Connect Version Control Integration", description: "Connect to your version control provider."},
      configure_vcs_provider: {title: "Configure Version Control Integration", description: "Configure your version control provider integration."},
      step_foo: {title: "Step Foo", description: "Description for step foo."}
    }.freeze

    def initialize(app:, onboarding_state:, show_back_button: false, show_next_button: false)
      @app = app
      @onboarding_state = onboarding_state
      @show_back_button = show_back_button
      @show_next_button = show_next_button
    end

    delegate :current_step?, to: :helpers
    delegate :step_completed?, to: :@onboarding_state

    def steps
      OnboardingState::STEPS
    end

    def show_back_button?
      @show_back_button
    end

    def show_next_button?
      @show_next_button
    end

    def previous_step
      helpers.previous_step if show_back_button?
    end

    def next_step
      helpers.next_step if show_next_button?
    end

    def navigation_button_classes
      if show_back_button? && show_next_button?
        "flex justify-between mt-4"
      elsif show_back_button?
        "flex justify-start mt-4"
      else
        "flex justify-end mt-4"
      end
    end

    def back_button_classes
      "px-5 py-2.5 text-sm font-medium text-gray-900 bg-white border border-gray-200 rounded-lg focus:outline-none hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700"
    end

    def next_button_classes
      "text-white bg-blue-600 hover:bg-blue-700 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
    end
  end
end
