class Onboarding::WizardComponent < BaseComponent
  renders_many :steps, Onboarding::StepComponent

  def initialize(current_step:, onboarding_state:)
    @current_step = current_step
    @onboarding_state = onboarding_state
  end

  attr_reader :current_step, :onboarding_state
end
