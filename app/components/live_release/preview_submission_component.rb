# frozen_string_literal: true

class LiveRelease::PreviewSubmissionComponent < BaseComponent
  def initialize(submission)
    @submission = submission
  end

  attr_reader :submission
  delegate :store_release, to: :submission

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
