class BetaSoaksController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!
  before_action :set_release
  before_action :set_beta_soak

  def show
    live_release!
    set_train_and_app
  end

  def end_soak
    if Action.end_soak_period!(@beta_soak, current_user).ok?
      redirect_to release_beta_soak_path(@release), notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure")}
    end
  end

  def extend_soak
    additional_hours = params[:additional_hours].to_i
    additional_hours = 1 if additional_hours <= 0

    res = Action.extend_soak_period!(@beta_soak, additional_hours, current_user)

    if res.ok?
      redirect_to release_beta_soak_path(@release), notice: t(".success", hours: additional_hours)
    else
      redirect_back fallback_location: root_path, flash: {error: res.error.message}
    end
  end

  private

  def set_release
    @release =
      Release
        .joins(train: :app)
        .where(apps: {organization: current_organization})
        .friendly.find(params[:release_id])
  end

  def set_beta_soak
    @beta_soak = @release.beta_soak
  end

  def set_train_and_app
    @train = @release.train
    @app = @train.app
    set_current_app
  end
end
