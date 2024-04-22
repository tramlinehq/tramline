class ReleaseIndicesController < SignedInApplicationController
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_tab_configuration, only: %i[edit update]

  def edit
    @release_index = @train.release_index
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

  def set_tab_configuration
    @tab_configuration = [
      [1, "General", edit_app_train_path(@app, @train), "v2/cog.svg"],
      [2, "Steps", steps_app_train_path(@app, @train), "v2/route.svg"],
      [3, "Notification Settings", app_train_notification_settings_path(@app, @train), "bell.svg"],
      ([4, "Release Health", rules_app_train_path(@app, @train), "v2/heart_pulse.svg"] if current_user.release_monitoring?),
      [5, "Reldex Settings", edit_app_train_release_index_path(@app, @train), "v2/ruler.svg"]
    ].compact
  end
end
