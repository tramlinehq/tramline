# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::SubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission, inactive: false)
    @submission = submission
    @inactive = inactive
  end

  attr_reader :submission, :inactive
  delegate :build, :release_platform_run, :external_link, to: :submission
  delegate :release, to: :release_platform_run

  def status_border
    return STATUS_BORDER_COLOR_PALETTE[:failure] if submission.failed?
    return STATUS_BORDER_COLOR_PALETTE[:success] if submission.finished?
    STATUS_BORDER_COLOR_PALETTE[:neutral]
  end

  def last_activity_at
    ago_in_words(last_activity_ts)
  end

  def last_activity_ts
    if submission.store_rollout.present?
      submission.store_rollout.completed_at
    else
      submission.approved_at || submission.prepared_at || submission.created_at
    end
  end

  def last_activity_tooltip
    "Last activity at #{time_format(last_activity_ts)}"
  end

  def external_status
    submission.store_status&.humanize || NOT_AVAILABLE
  end

  def status
    submission.status.humanize
  end

  def submission_logo
    "integrations/logo_#{submission.provider}.png"
  end

  def submission_logo_bw
    "v2/logo_#{submission.provider}_bw.svg"
  end
end
