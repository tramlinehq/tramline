# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  deployment_channel      :jsonb
#  failure_reason          :string
#  name                    :string
#  prepared_at             :datetime
#  rejected_at             :datetime
#  status                  :string           not null
#  store_link              :string
#  store_release           :jsonb
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
#  pre_prod_release_id     :uuid             indexed
#  production_release_id   :bigint           indexed
#  release_platform_run_id :uuid             not null, indexed
#
class AppStoreSubmission < StoreSubmission
  using RefinedArray
  using RefinedString

  RETRYABLE_FAILURE_REASONS = [:attachment_upload_in_progress]
  STATES = STATES.merge(
    submitting_for_review: "submitting_for_review",
    submitted_for_review: "submitted_for_review",
    approved: "approved",
    cancelled: "cancelled"
  )
  FINAL_STATES = %w[approved]
  IMMUTABLE_STATES = %w[approved submitted_for_review]
  CHANGEABLE_STATES = STATES.values - IMMUTABLE_STATES
  STAMPABLE_REASONS = %w[
    prepare_release_failed
    submitted_for_review
    resubmitted_for_review
    review_approved
    review_failed
  ]

  PreparedVersionNotFoundError = Class.new(StandardError)
  SubmissionNotInTerminalState = Class.new(StandardError)

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

    event :start_prepare, guard: :startable?, after_commit: :on_start_prepare! do
      transitions from: [:created, :failed_prepare, :prepared, :failed, :review_failed, :cancelled], to: :preparing
    end

    event :finish_prepare, after_commit: :on_finish_prepare! do
      after { set_prepared_at! }
      transitions from: :preparing, to: :prepared
    end

    event :fail_prepare, before: :set_failure_reason, after_commit: :on_fail_prepare! do
      transitions from: :preparing, to: :failed_prepare
    end

    event :start_submission, after_commit: :on_start_submission! do
      transitions from: :prepared, to: :submitting_for_review
    end

    event :submit_for_review, after_commit: :on_submit_for_review! do
      after { set_submitted_at! }
      transitions from: [:review_failed, :submitting_for_review], to: :submitted_for_review
    end

    event :reject do
      after { set_rejected_at! }
      transitions from: :submitted_for_review, to: :review_failed
    end

    event :approve do
      after { set_approved_at! }
      transitions from: :submitted_for_review, to: :approved
    end

    event :start_cancellation, after_commit: :on_start_cancellation! do
      transitions from: :submitted_for_review, to: :cancelling
    end

    event :cancel do
      transitions from: [:submitted_for_review, :cancelling], to: :cancelled
    end

    event :fail, before: :set_failure_reason do
      transitions to: :failed
    end
  end

  def change_allowed?
    status.in? CHANGEABLE_STATES
  end

  def locked?
    status.in? FINAL_STATES
  end

  def finished?
    status.in? FINAL_STATES
  end

  def cancellable? = submitted_for_review?

  def reviewable? = prepared?

  def requires_review? = true

  def staged_rollout? = true # FIXME - get this configuration from train settings

  def on_start_prepare!
    StoreSubmissions::AppStore::PrepareForReleaseJob.perform_async(id)
  end

  def prepare_for_release!
    result = provider.prepare_release(build_number, version_name, staged_rollout?, release_metadatum, true)

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

    update_store_info!(result.value!)
    finish_prepare!
  end

  def on_start_submission!
    StoreSubmissions::AppStore::SubmitForReviewJob.perform_async(id)
  end

  def submit!
    result = provider.submit_release(build_number, version_name)

    unless result.ok?
      return update(failure_reason: result.error.reason) if result.error.reason.in? RETRYABLE_FAILURE_REASONS
      return fail_with_error(result.error)
    end

    submit_for_review!
  end

  def on_submit_for_review!(args = {resubmission: false})
    resubmission = args.fetch(:resubmission)
    notify!("Submitted for review!", :submit_for_review, notification_params.merge(resubmission:))

    stamp_params = {kind: :notice, data: stamp_data}
    stamp_params[:reason] = resubmission ? :resubmitted_for_review : :submitted_for_review
    event_stamp!(**stamp_params)
  end

  def on_finish_prepare!
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.perform_async(id)
  end

  def update_external_release
    return if locked?

    result = provider.find_release(build_number)

    unless result.ok?
      elog(result.error)
      raise SubmissionNotInTerminalState, "Retrying in some time..."
    end

    release_info = result.value!
    update_store_info!(release_info)

    if release_info.success?
      approved!
      return
    elsif release_info.review_cancelled?
      cancel! unless cancelled?
    elsif release_info.waiting_for_review? && review_failed?
      # A failed review was re-submitted or responded to outside Tramline
      submit_for_review!(resubmission: true)
    elsif release_info.review_failed? && !review_failed?
      reject!
    end

    raise SubmissionNotInTerminalState, "Retrying in some time..."
  end

  def on_start_cancellation!
    StoreSubmissions::AppStore::RemoveFromReviewJob.perform_async(id)
  end

  def remove_from_review!
    result = provider.remove_from_review(build_number, version_name)

    unless result.ok?
      return fail_with_error(result.error)
    end

    update_store_info!(result.value!)
    cancel!
  end

  # FIXME: update store version details when release metadata changes or build is updated
  def update_store_version
    # update whats new, build
  end

  def update_store_info!(release_info)
    self.store_release = release_info.release_info
    self.store_status = release_info.attributes[:status]
    self.store_link = release_info.attributes[:external_link]
    save!
  end

  def on_fail_prepare!
    event_stamp!(reason: :prepare_release_failed, kind: :error, data: stamp_data)
  end
end
