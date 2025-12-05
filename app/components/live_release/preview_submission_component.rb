# frozen_string_literal: true

class LiveRelease::PreviewSubmissionComponent < BaseComponent
  include Memery

  def initialize(submission)
    @submission = submission
  end

  attr_reader :submission

  def localizations
    release_info.attributes["localizations"]
  end

  def languages
    localizations.pluck("language")
  end

  def phased_release_enabled?
    release_info.attributes["phased_release_status"].present?
  end

  def show_existing_review_items
    existing_review_items.map { |item| "#{item[:type]} (#{item[:id]})" }.join(", ")
  end

  memoize def existing_review_items
    release_info.existing_review_submission_items
  end

  delegate :existing_review_submission_link, to: :release_info

  memoize def release_info
    submission.provider.release_info(submission.store_release.with_indifferent_access)
  end
end
