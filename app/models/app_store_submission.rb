# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  config                  :jsonb
#  failure_reason          :string
#  name                    :string
#  parent_release_type     :string           indexed => [parent_release_id]
#  prepared_at             :datetime
#  rejected_at             :datetime
#  sequence_number         :integer          default(0), not null, indexed
#  status                  :string           not null
#  store_link              :string
#  store_release           :jsonb
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  parent_release_id       :uuid             indexed => [parent_release_type]
#  release_platform_run_id :uuid             not null, indexed
#
class AppStoreSubmission < StoreSubmission
  using RefinedArray
  using RefinedString
  include Displayable

  has_one :app_store_rollout,
    foreign_key: :store_submission_id,
    dependent: :destroy,
    inverse_of: :app_store_submission

  RETRYABLE_FAILURE_REASONS = [:attachment_upload_in_progress]
  STATES = {
    created: "created",
    preparing: "preparing",
    prepared: "prepared",
    failed_prepare: "failed_prepare",
    submitting_for_review: "submitting_for_review",
    submitted_for_review: "submitted_for_review",
    review_failed: "review_failed",
    approved: "approved",
    failed: "failed",
    cancelling: "cancelling",
    cancelled: "cancelled"
  }
  FINAL_STATES = %w[approved]
  IMMUTABLE_STATES = %w[preparing approved submitting_for_review submitted_for_review cancelling]
  PRE_PREPARE_STATES = %w[created preprocessing cancelled review_failed failed]
  CHANGEABLE_STATES = %w[created preprocessing prepared cancelled review_failed failed approved]
  CANCELABLE_STATES = %w[submitted_for_review]
  STAMPABLE_REASONS = %w[
    prepare_release_failed
    submitted_for_review
    resubmitted_for_review
    review_approved
    review_rejected
    cancellation_failed
    cancelled
    failed
  ]

  PreparedVersionNotFoundError = Class.new(StandardError)
  SubmissionNotInTerminalState = Class.new(StandardError)

  enum :status, STATES
  enum :failure_reason, {
    invalid_release: "invalid_release",
    unknown_failure: "unknown_failure",
    developer_rejected: "developer_rejected"
  }.merge(Installations::Apple::AppStoreConnect::Error.reasons.zip_map_self)

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start_prepare, after_commit: :on_start_prepare! do
      transitions to: :preparing
    end

    event :finish_prepare do
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

    event :reject, after_commit: :on_reject! do
      after { set_rejected_at! }
      transitions from: :submitted_for_review, to: :review_failed
    end

    event :approve, after_commit: :on_approve! do
      after { set_approved_at! }
      transitions from: [:submitted_for_review, :cancelling], to: :approved
    end

    event :start_cancellation, after_commit: :on_start_cancellation! do
      transitions from: :submitted_for_review, to: :cancelling
    end

    event :cancel, after_commit: :on_cancel! do
      transitions from: [:submitted_for_review, :approved, :cancelling], to: :cancelled
    end

    event :fail, before: :set_failure_reason, after_commit: :on_fail! do
      transitions to: :failed
    end
  end

  after_create_commit :poll_external_status

  def pre_review? = PRE_PREPARE_STATES.include?(status) && editable?

  def change_build? = CHANGEABLE_STATES.include?(status) && editable?

  def cancellable? = CANCELABLE_STATES.include?(status) && editable?

  def finished? = FINAL_STATES.include?(status) && store_rollout.finished?

  def post_review? = FINAL_STATES.include?(status)

  def reviewable? = prepared? && editable?

  def external_link
    return provider.inflight_store_link if parent_release.inflight?
    return provider.deliverable_store_link if parent_release.active?
    store_link
  end

  def trigger!
    return unless actionable?

    start_prepare!
  end

  def retrigger!
    return unless created? || cancelled?

    reset_store_info!
    trigger!
  end

  def prepare_for_release!
    result = provider.prepare_release(build_number, version_name, staged_rollout?, notes, true)

    unless result.ok?
      case result.error.reason
      when :release_not_found then raise PreparedVersionNotFoundError
      when :release_already_exists then fail_prepare!(reason: result.error.reason)
      else fail_with_error!(result.error)
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
      return fail_with_error!(result.error)
    end

    submit_for_review!
  end

  def update_external_release
    return unless editable?

    result = provider.find_release(build_number)

    unless result.ok?
      elog(result.error)
      raise SubmissionNotInTerminalState, "Retrying in some time..."
    end

    release_info = result.value!
    update_store_info!(release_info)

    if release_info.success?
      approve!
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

  def remove_from_review!
    result = provider.remove_from_review(build_number, version_name)

    if result.ok?
      update_store_info!(result.value!)
      cancel!
    else
      if result.error.reason == :submission_not_found
        update_external_release
      end

      failure_reason = "the submission being not in a cancellable state on the App Store"
      event_stamp!(reason: :cancellation_failed, kind: :error, data: stamp_data.merge(failure_reason:))
    end
  end

  def attach_build(build)
    return unless change_build?
    update(build:)
  end

  def find_build
    @build ||= provider.find_build(build_number)
  end

  def update_store_info!(release_info)
    self.store_release = release_info.release_info
    self.store_status = release_info.attributes[:status]
    self.store_link = release_info.attributes[:external_link]
    save!
  end

  # app.ios_store_provider
  def provider = conf.integrable.ios_store_provider

  def notification_params
    super.merge(
      requires_review: true,
      submission_channel: submission_channel.name
    )
  end

  private

  def release_notes
    release_metadata.map do |metadata|
      {
        whats_new: metadata.release_notes,
        promotional_text: metadata.promo_text,
        locale: metadata.locale
      }
    end
  end

  def poll_external_status
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.perform_later(id, can_retry: true)
  end

  def update_external_status
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.perform_later(id, can_retry: false)
  end

  def on_start_prepare!
    StoreSubmissions::AppStore::FindBuildJob.perform_async(id)
  end

  def on_submit_for_review!(args = {resubmission: false})
    resubmission = args.fetch(:resubmission)
    notify!("Production submission submitted for review", :production_submission_in_review, notification_params.merge(resubmission:))
    stamp_params = {kind: :notice, data: stamp_data}
    stamp_params[:reason] = resubmission ? :resubmitted_for_review : :submitted_for_review
    event_stamp!(**stamp_params)
    update_external_status
  end

  def on_start_cancellation!
    StoreSubmissions::AppStore::RemoveFromReviewJob.perform_async(id)
  end

  def on_cancel!
    event_stamp!(reason: :cancelled, kind: :error, data: stamp_data)
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.perform_later(id, can_retry: false)
  end

  def on_reject!
    event_stamp!(reason: :review_rejected, kind: :error, data: stamp_data)
    notify!("Production submission rejected", :production_submission_rejected, notification_params)
  end

  def on_approve!
    event_stamp!(reason: :review_approved, kind: :success, data: stamp_data)
    notify!("Production submission approved", :production_submission_approved, notification_params)
    create_app_store_rollout!(
      release_platform_run:,
      config: staged_rollout? ? conf.rollout_stages : [],
      is_staged_rollout: staged_rollout?
    )
  end

  def on_fail_prepare!
    event_stamp!(reason: :prepare_release_failed, kind: :error, data: stamp_data)
    notify!("Submission failed", :submission_failed, notification_params)
  end

  def on_fail!(args = nil)
    failure_error = args&.fetch(:error, nil)
    event_stamp!(reason: :failed, kind: :error, data: stamp_data(failure_message: failure_error&.message))
    notify!("Submission failed", :submission_failed, notification_params)
  end

  def update_store_version
    # TODO: [V2] [post-alpha] update store version details when release metadata changes or build is updated
    # update whats new, build
  end

  def build_present_in_store?
    find_build.ok?
  end
end
