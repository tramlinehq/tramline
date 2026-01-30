class OnboardingController < SignedInApplicationController
  include Wicked::Wizard
  before_action :set_onboarding_state

  steps(*OnboardingState::STEPS)

  def show
    render_wizard
  end

  def update
    handle_vcs_provider and return if step == :vcs_provider

    @onboarding_state.update(onboarding_state_params)
    flash[:notice] = I18n.t("onboarding.completed") if step == steps.last
    render_wizard @onboarding_state
  end

  def current_step
    step
  end
  helper_method :current_step, :current_step?, :previous_step, :next_step

  private

  def handle_vcs_provider
    @onboarding_state.assign_attributes(onboarding_state_params)
    if @onboarding_state.save(context: :vcs_provider_setup)
      render_wizard @onboarding_state
    else
      # redirect or render the same step with error, subsequently render the error in the view in the apt place
      redirect_back fallback_location: wizard_url(step), flash: {error: "#{@onboarding_state.errors.full_messages.to_sentence}."}
    end
  end

  def set_onboarding_state
    @onboarding_state = OnboardingState.find_or_create_by!(app: @app)
  end

  def onboarding_state_params
    params.require(:onboarding_state).permit(:vcs_provider)
  end

  def finish_wizard_path
    app_path(@app)
  end
end
