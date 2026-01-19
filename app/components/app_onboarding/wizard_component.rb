module AppOnboarding
  class WizardComponent < ViewComponent::Base
    STEPS = [
      {key: :step_1, title: "Step 1", index: 1, description: "Step 1 description"},
      {key: :step_2, title: "Step 2", index: 2, description: "Step 2 description"},
      {key: :step_3, title: "Step 3", index: 3, description: "Step 3 description"}
    ].freeze

    def initialize(app:, onboarding_state:, current_step:, show_back: false, show_next: false)
      @app = app
      @onboarding_state = onboarding_state
      @current_step = current_step
      @show_back = show_back
      @show_next = show_next
    end

    def render?
      true
    end

    def steps
      STEPS
    end

    def current_step_config
      STEPS.find { |s| s[:key] == @current_step }
    end

    def show_back_button?
      @show_back
    end

    def show_next_button?
      @show_next
    end

    def previous_step
      STEPS[current_step_index - 1]&.dig(:key) if show_back_button?
    end

    def next_step
      STEPS[current_step_index + 1]&.dig(:key) if show_next_button?
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

    private

    def current_step_index
      STEPS.find_index { |s| s[:key] == @current_step } || 0
    end
  end
end
