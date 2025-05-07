class ScheduledReleasesController < SignedInApplicationController
  include Loggable

  before_action :require_write_access!, only: %i[skip resume]
  before_action :set_train, only: %i[skip resume]
  before_action :set_scheduled_release, only: %i[skip resume]

  def skip
    if @scheduled_release.manually_skip
      redirect_to train_path, notice: t(".success")
    else
      train_redirect_back(t(".fail"))
    end
  end

  def resume
    if @scheduled_release.manually_resume
      redirect_to train_path, notice: t(".success")
    else
      train_redirect_back(t(".fail"))
    end
  end

  private

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_scheduled_release
    @scheduled_release = @train.scheduled_releases.find(params[:id])
  end

  def train_path
    app_train_releases_path(@app, @train)
  end

  def train_redirect_back(message)
    redirect_back fallback_location: train_path, flash: {error: message}
  end
end
