class ReleasePlatformsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_tab_configuration, only: %i[edit update]
  # before_action :ensure_editable, only: %i[edit update]

  def edit
    @selected_platform = @train.release_platforms.where(platform: params[:id]).first
    @other_platform = @train.release_platforms.where.not(platform: params[:id]).first
    # binding.pry
  end

  def update
  end

  private

  def set_train
    @train = Train.friendly.find(params[:train_id])
  end

  def set_app_from_train
    @app = @train.app
  end

  def platform_params

  end

  def ensure_editable
    unless @release_platform_run.metadata_editable?
      redirect_back fallback_location: release_path(@release), flash: {error: t(".metadata_not_editable")}
    end
  end

  def set_tab_configuration
    @tab_configuration = [
      [1, "Release Settings", edit_app_train_path(@app, @train), "v2/cog.svg"],
      # [2, "Workflow Settings", steps_app_train_path(@app, @train), "v2/route.svg"],
      [2, "Submissions Settings", edit_app_train_platform_path(@app, @train, @train.release_platforms.first.platform), "v2/route.svg"],
      [3, "Notification Settings", app_train_notification_settings_path(@app, @train), "bell.svg"],
      [4, "Release Health Rules", rules_app_train_path(@app, @train), "v2/heart_pulse.svg"],
      [5, "Reldex Settings", edit_app_train_release_index_path(@app, @train), "v2/ruler.svg"]
    ].compact
  end
end
