class ReleaseMetadataController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_release, only: %i[edit update edit_all update_all]
  before_action :set_release_platform, only: %i[edit update]
  before_action :set_release_platform_run, only: %i[edit update]
  before_action :set_train, only: %i[edit update edit_all update_all]
  before_action :set_app_from_train, only: %i[edit update edit_all update_all]
  before_action :ensure_editable, only: %i[edit update]

  def edit
    @release_metadatum = @release_platform_run.release_metadatum
  end

  def update
    @release_metadatum = ReleaseMetadata.find(params[:id])

    if @release_metadatum.update(release_metadata_params)
      redirect_to release_path(@release), notice: "Release metadata was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_all
    @active_languages = @release.active_languages
    @language = params[:language] || @active_languages.first
    @stream_id = "release-metadata"

    @ios_metadata = @release.ios_release_platform_run&.metadata_for(@language)
    @android_metadata = @release.android_release_platform_run&.metadata_for(@language)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update_all
    language = params.require(:language)
    ios_params = params.require(:ios).permit(:id, :release_notes, :promo_text) if params.key?(:ios)
    android_params = params.require(:android).permit(:id, :release_notes) if params.key?(:android)

    ios_id = ios_params&.delete(:id)
    android_id = android_params&.delete(:id)

    if ios_id.blank? && android_id.blank?
      render :edit_all, status: :unprocessable_entity
      return
    end

    ios_metadata = ReleaseMetadata.find_by_id_and_language(ios_id, language, :ios)
    android_metadata = ReleaseMetadata.find_by_id_and_language(android_id, language, :android)

    if update_all_platforms(android_metadata, android_params, ios_metadata, ios_params)
      redirect_to release_metadata_edit_path(@release), notice: "Release metadata was successfully updated."
    else
      render :edit_all, status: :unprocessable_entity
    end
  end

  private

  def update_all_platforms(android_metadata, android_params, ios_metadata, ios_params)
    ReleaseMetadata.transaction do
      android_metadata.update(android_params) if android_params.present?
      ios_metadata.update(ios_params) if ios_params.present?
      true
    end
  rescue ActiveRecord::RecordInvalid
    false
  end

  def release_metadata_params
    params.require(:release_metadata).permit(:release_notes, :promo_text)
  end

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def set_release_platform
    @release_platform = @release.release_platforms.friendly.find(params[:release_platform_id])
  end

  def set_release_platform_run
    @release_platform_run = @release.release_platform_runs.find_by(release_platform: @release_platform)
  end

  def set_train
    @train = @release.train
  end

  def set_app_from_train
    @app = @train.app
  end

  def ensure_editable
    unless @release_platform_run.metadata_editable?
      redirect_back fallback_location: release_path(@release),
                    flash: { error: "Cannot update the release metadata once the production release has begun." }
    end
  end
end
