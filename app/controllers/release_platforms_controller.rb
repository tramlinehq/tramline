class ReleasePlatformsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[edit]
  before_action :set_app, only: %i[show edit]
  before_action :set_train, only: %i[show edit]
  before_action :set_release_platform, only: %i[show edit]
  around_action :set_time_zone

  def show
  end

  def edit
  end

  private

  def set_release_platform
    @release_platform = @train.release_platforms.friendly.find(params[:id])
  end

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end
end
