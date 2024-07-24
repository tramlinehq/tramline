# frozen_string_literal: true

class V2::LiveRelease::PreProdSubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission, inactive: false)
    @submission = submission
    @inactive = inactive
  end

  attr_reader :submission, :inactive
  delegate :build, :release_platform_run, :external_link, to: :submission
  delegate :release, to: :release_platform_run

  def status_border
    return "border-red-400" if submission.failed?
    "border-green-400"
  end

  def released_at
    released_at = if submission.store_rollout.present?
                    submission.store_rollout.completed_at
                  else
                    submission.approved_at || submission.prepared_at
                  end
    ago_in_words(released_at)
  end
end
