# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  failure_reason          :string
#  name                    :string
#  prepared_at             :datetime
#  rejected_at             :datetime
#  status                  :string           not null
#  store_link              :string
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
#  release_platform_run_id :uuid             not null, indexed
#
class AppStoreSubmission < StoreSubmission
  using RefinedArray
  using RefinedString

  STATES = {
    created: "created",
    preparing: "preparing",
    prepared: "prepared",
    failed_prepare: "failed_prepare",
    submitted_for_review: "submitted_for_review",
    review_failed: "review_failed",
    approved: "approved",
    failed: "failed"
  }

  IMMUTABLE_STATES = %w[approved submitted_for_review]
  CHANGEABLE_STATES = STATES.values - IMMUTABLE_STATES

  STAMPABLE_REASONS = %w[
    prepare_release_failed
    inflight_release_replaced
    submitted_for_review
    resubmitted_for_review
    review_approved
    review_failed
  ]

  RETRYABLE_FAILURE_REASONS = [:attachment_upload_in_progress]

  PreparedVersionNotFoundError = Class.new(StandardError)
  ExternalReleaseNotInTerminalState = Class.new(StandardError)

  enum status: STATES

  enum failure_reason: {
    developer_rejected: "developer_rejected",
    invalid_release: "invalid_release",
    unknown_failure: "unknown_failure"
  }.merge(Installations::Apple::AppStoreConnect::Error.reasons.zip_map_self)

  # Things that have happened before Store Submission
  # 1. Build has been created and available in TestFlight
  # 2. Build has sent for beta testing to external groups (optionally)
  # 3. Beta soak has ended (if configured)
  # 4. Release metadata has been updated
  #
  # Things that will happen during Store Submission
  # 1. Prepare for release
  # 2. Submit for review
  # 3. Review
  # 4. Approve/Reject
  # 5. Cancel submission
  #
  # Things that will happen after Store Submission
  # 1. Rollout (phased or otherwise)

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start_prepare,
      guard: :startable?,
      after_commit: ->(args = {force: false}) { StoreSubmissions::AppStore::PrepareForReleaseJob.perform_async(id, args.fetch(:force)) } do
      transitions from: [:created, :failed_prepare, :prepared, :failed], to: :preparing
    end

    event :finish_prepare do
      after { set_prepared_at! }
      transitions from: :preparing, to: :prepared
    end

    event :fail_prepare, before: :set_reason, after_commit: -> { event_stamp!(reason: :prepare_release_failed, kind: :error, data: stamp_data) } do
      transitions from: :preparing, to: :failed_prepare
    end

    event :submit_for_review, after_commit: ->(args = {resubmission: false}) { after_submission(args.fetch(:resubmission)) } do
      after { set_submitted_at! }
      transitions from: [:prepared, :review_failed], to: :submitted_for_review
    end

    event :reject do
      after { set_rejected_at! }
      transitions from: :submitted_for_review, to: :review_failed
    end

    event :approve do
      after { set_approved_at! }
      transitions from: :submitted_for_review, to: :approved
    end

    event :fail, before: :set_reason do
      transitions to: :failed
    end

    event :cancel do
      transitions from: :submitted_for_review, to: :cancelled
    end
  end

  def change_allowed?
    status.in? CHANGEABLE_STATES
  end

  def reviewable? = true

  # FIXME
  def staged_rollout? = true

  def integration_type = :app_store

  def prepare_for_release!(force: false)
    result = provider.prepare_release(build_number, version_name, staged_rollout?, release_metadata, force)

    unless result.ok?
      case result.error.reason
      when :release_not_found then raise PreparedVersionNotFoundError
      when :release_already_exists then fail_prepare!(reason: result.error.reason)
      else fail_with_error(result.error)
      end

      return
    end

    unless result.value!.valid?(build_number, version_name, staged_rollout?)
      fail!(reason: :invalid_release)
      return
    end

    finish_prepare!
    event_stamp!(reason: :inflight_release_replaced, kind: :notice, data: stamp_data) if force
  end

  def submit!
    result = provider.submit_release(build_number, version_name)

    unless result.ok?
      return update(failure_reason: result.error.reason) if result.error.reason.in? RETRYABLE_FAILURE_REASONS
      return fail_with_error(result.error)
    end

    submit_for_review!
  end

  def after_submission(resubmission = false)
    notify!("Submitted for review!", :submit_for_review, notification_params.merge(resubmission:))
    if resubmission
      event_stamp!(reason: :resubmitted_for_review, kind: :notice, data: stamp_data)
    else
      event_stamp!(reason: :submitted_for_review, kind: :notice, data: stamp_data)
    end
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.perform_async(id)
  end

  def update_external_release
    result = provider.find_release(build_number)

    unless result.ok?
      elog(result.error)
      raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
    end

    release_info = result.value!
    self.store_status = release_info.status
    save!

    if release_info.success?
      approved!
    elsif release_info.failed?
      fail!(reason: :developer_rejected)
    elsif release_info.waiting_for_review? && review_failed?
      # A failed review was re-submitted or responded to outside Tramline
      submit_for_review!(resubmission: true)
    else
      reject! if release_info.review_failed? && !review_failed?
      raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
    end
  end

  def developer_reject!
    fail!(reason: :developer_rejected)
  end

  # FIXME: update store version details when release metadata changes or build is updated
  def update_store_version
    # update whats new, build
  end
end
