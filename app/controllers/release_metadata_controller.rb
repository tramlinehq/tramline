class ReleaseMetadataController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit update]
  before_action :set_release, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app, only: %i[edit update]
  before_action :ensure_editable, only: %i[edit update]

  def edit
    @release_metadata = @release.release_metadata
  end

  def update
    @release_metadata = ReleaseMetadata.find_or_initialize_by(release: @release)

    if @release_metadata.update(release_metadata_params)
      redirect_to parent_release_path, notice: "Release metadata was successfully updated."
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

  def set_app
    @app = @train.app
  end

  def set_release
    @release = Release.find(params[:release_group_id])
  end

  def parent_release_path
    release_group_path(@release)
  end

  def ensure_editable
    unless @release.metadata_editable?
      redirect_back fallback_location: parent_release_path,
        flash: {error: "Cannot update the release metadata once the production release has begun."}
    end
  end
end
