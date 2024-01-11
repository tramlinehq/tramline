class ReleaseMetadataController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit update]
  before_action :set_release_platform_run, only: %i[edit update]
  before_action :set_release, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :ensure_editable, only: %i[edit update]

  def edit
    @release_metadata = @release_platform_run.release_metadata
  end

  def update
    @release_metadata = ReleaseMetadata.find_or_initialize_by(release_platform_run: @release_platform_run)

    if @release_metadata.update(release_metadata_params)
      redirect_to release_path(@release), notice: "Release metadata was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def release_metadata_params
    params.require(:release_metadata).permit(
      :release_notes,
      :promo_text
    )
  end

  def set_train
    @train = @release.train
  end

  def set_app_from_train
    @app = @train.app
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:release_platform_run_id])
  end

  def set_release
    @release = @release_platform_run.release
  end

  def ensure_editable
    unless @release_platform_run.metadata_editable?
      redirect_back fallback_location: release_path(@release),
        flash: {error: "Cannot update the release metadata once the production release has begun."}
    end
  end
end
