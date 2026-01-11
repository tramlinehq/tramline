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
    handle_step_2 and return if step == :step_2

    @onboarding_state.update(onboarding_state_params)
    flash[:notice] = "Onboarding completed!" if step == steps.last
    render_wizard @onboarding_state
  end

  private

  def handle_step_2
    if onboarding_state_params[:field_2].present?
      @onboarding_state.update(onboarding_state_params)
      render_wizard @onboarding_state
    else
      @onboarding_state.errors.add(:field_2, "can't be blank")
      # redirect or render the same step with error, subsequently render the error in the view in the apt place
      redirect_back fallback_location: wizard_url(step), flash: {error: "#{@onboarding_state.errors.full_messages.to_sentence}."}
    end
  end

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
