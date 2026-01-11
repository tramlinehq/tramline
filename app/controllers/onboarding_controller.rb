class OnboardingController < SignedInApplicationController
  include Wicked::Wizard
  before_action :set_onboarding_state

  steps :step_1,
        :step_2,
        :step_3

  def show
    render_wizard
  end

  def update
    @onboarding_state.update(onboarding_state_params)
    render_wizard @onboarding_state
  end

  private

  def set_onboarding_state
    @onboarding_state = OnboardingState.find_or_create_by!(app: @app)
  end

  def onboarding_state_params
    params.require(:onboarding_state).permit(:field_1, :field_2, :field_3)
  end

  def finish_wizard_path
    app_path(@app)
  end
end
