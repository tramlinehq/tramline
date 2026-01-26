class ReleaseMetadataController < SignedInApplicationController
  include Tabbable

  before_action :set_release, only: %i[index update_all]
  before_action :set_train, only: %i[index update_all]
  before_action :set_app_from_train, only: %i[index update_all]

  def index
    set_metadata

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update_all
    language = params.require(:language)
    rm_params = params.require(:release_metadata)
    ios_params = rm_params.require(:ios).permit(:id, :release_notes, :promo_text) if rm_params.key?(:ios)
    android_params = rm_params.require(:android).permit(:id, :release_notes) if rm_params.key?(:android)

    ios_id = ios_params&.delete(:id)
    android_id = android_params&.delete(:id)

    if ios_id.blank? && android_id.blank?
      set_metadata
      flash.now[:error] = t(".generic_failure")

      render :index, status: :unprocessable_entity
      return
    end

    ios_metadata = ReleaseMetadata.find_by_id_and_language(ios_id, language, :ios)
    android_metadata = ReleaseMetadata.find_by_id_and_language(android_id, language, :android)

    begin
      ReleaseMetadata.transaction do
        android_metadata.update!(android_params.merge(draft_release_notes: nil)) if android_id.present?
        ios_metadata.update!(ios_params.merge(draft_release_notes: nil, draft_promo_text: nil)) if ios_id.present?
      end

      redirect_to release_metadata_edit_path(@release), notice: t(".success")
    rescue ActiveRecord::RecordInvalid
      save_drafts(android_metadata, android_params, ios_metadata, ios_params)
      set_metadata
      flash.now[:error] ||= []
      flash.now[:error] << android_metadata&.errors&.full_messages&.to_sentence
      flash.now[:error] << ios_metadata&.errors&.full_messages&.to_sentence
      flash.now[:notice] = t(".draft_saved")

      render :index, status: :unprocessable_entity
    end
  end

  private

  def save_drafts(android_metadata, android_params, ios_metadata, ios_params)
    if android_metadata.present? && android_params.present?
      android_metadata.update_columns(draft_release_notes: android_params[:release_notes])
    end

    if ios_metadata.present? && ios_params.present?
      ios_metadata.update_columns(
        draft_release_notes: ios_params[:release_notes],
        draft_promo_text: ios_params[:promo_text]
      )
    end
  end

  def set_metadata
    @active_languages = @release.active_languages
    @language = params[:language] || @active_languages.first
    @stream_id = "release-metadata"

    @ios_metadata = @release.ios_release_platform_run&.metadata_for(@language, :ios)
    @android_metadata = @release.android_release_platform_run&.metadata_for(@language, :android)
  end

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def set_train
    @train = @release.train
  end

  def set_app_from_train
    @app = @train.app
    set_current_app
  end
end
