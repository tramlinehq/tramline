# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::SubmissionComponent < V2::BaseComponent
  include Memery
  CUSTOM_BOX_STYLE = "border-l-8 rounded-lg %s border-default-t border-default-b border-default-r box-padding rounded-r-lg"
  STATUS = {
    created: {text: "Not started", status: :inert},
    preprocessing: {text: "Processing", status: :ongoing, kind: :spinner_pill},
    preparing: {text: "Processing", status: :ongoing, kind: :spinner_pill},
    prepared: {text: "Prepared", status: :ongoing},
    failed_prepare: {text: "Failed to submit", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    approved: {text: "Review approved", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure},
    cancelled: {text: "Removed from review", status: :inert},
    finished: {text: "Finished", status: :success}
  }

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

  def custom_box_style
    CUSTOM_BOX_STYLE % status_border
  end

  def last_activity_ts
    if submission.store_rollout.present?
      submission.store_rollout.completed_at || submission.store_rollout.updated_at
    else
      submission.approved_at || submission.prepared_at || submission.updated_at
    end
  end

  def last_activity_tooltip
    "Last activity at #{time_format(last_activity_ts)}"
  end

  def last_activity_tick?
    %w[preprocessing preparing].include?(submission.status)
  end

  def status
    return STATUS[:finished] if submission.finished?
    status_picker(STATUS, submission.status)
  end

  def external_status
    submission.store_status&.humanize || NOT_AVAILABLE
  end

  def submission_logo_bw
    "v2/logo_#{submission.provider}_bw.svg"
  end

  def submission_logo
    "integrations/logo_#{submission.provider}.png"
  end

  def active?
    !@inactive
  end

  def title
    if active?
      "submission"
    else
      "upcoming submission"
    end
  end
end
