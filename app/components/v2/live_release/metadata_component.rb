class V2::LiveRelease::MetadataComponent < V2::BaseComponent
  def initialize(release, active_languages, language, ios_metadata: nil, android_metadata: nil)
    raise ArgumentError, "must have at least one of ios or android metadata" if ios_metadata.nil? && android_metadata.nil?

    @release = release
    @active_languages = active_languages
    @language = language
    @ios_metadata = ios_metadata
    @android_metadata = android_metadata
  end

  attr_reader :active_languages, :language, :android_metadata, :ios_metadata

  def edit_metadata_url
    release_metadata_edit_url(@release)
  end

  def update_metadata_path
    release_metadata_update_path(@release)
  end

  def no_locale_set
    text = "No #{language} locale set for this platform. Please contact support if you'd like to get this added."
    V2::EmptyStateComponent.new(banner_image: "languages.svg", text: text, type: :subdued)
  end

  def editable?
    @release.release_platform_runs.any?(&:metadata_editable?)
  end
end
