class Onboarding::WizardComponent < BaseComponent
  renders_many :steps, Onboarding::StepComponent
  renders_one :active_step
  renders_one :navigation_buttons

  def initialize(current_step:)
    @current_step = current_step
  end

  attr_reader :current_step
end
