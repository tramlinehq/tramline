class V2::LiveRelease::SubmissionStoreReleaseComponent < V2::BaseComponent
  def initialize(store_release:, submission:)
    @store_release = store_release
    @submission = submission
  end

  attr_reader :store_release, :submission

  def localizations
    store_release["localizations"]
  end

  def languages
    localizations.pluck("language")
  end

  def phased_release_enabled?
    store_release["phased_release_status"].present?
  end
end
