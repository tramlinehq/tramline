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
class PlayStoreSubmission < StoreSubmission
  using RefinedArray
  using RefinedString

  has_one :play_store_rollout,
    foreign_key: :store_submission_id,
    dependent: :destroy,
    inverse_of: :play_store_submission

  STAMPABLE_REASONS = %w[
    prepared
    review_rejected
    finished_manually
  ]
  STATES = {
    created: "created",
    preprocessing: "preprocessing",
    preparing: "preparing",
    prepared: "prepared",
    review_failed: "review_failed",
    failed: "failed",
    failed_with_action_required: "failed_with_action_required",
    finished_manually: "finished_manually"
  }
  FINAL_STATES = %w[prepared]
  PRE_PREPARE_STATES = %w[created preprocessing review_failed failed]
  CHANGEABLE_STATES = %w[created preprocessing failed prepared]
  MAX_NOTES_LENGTH = 500

  enum failure_reason: {
    unknown_failure: "unknown_failure"
  }.merge(Installations::Google::PlayDeveloper::Error.reasons.zip_map_self)
  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :preprocess do
      transitions from: :created, to: :preprocessing
    end

    event :start_prepare, after: :on_start_prepare! do
      transitions from: [:created, :preprocessing, :prepared, :failed], to: :preparing
    end

    event :finish_prepare, after_commit: :on_prepare! do
      after do
        set_prepared_at!
        set_approved_at!
      end
      transitions from: :preparing, to: :prepared
    end

    # TODO: [V2] [post-alpha] This is currently not used, should be hooked up as an action from the user
    event :reject do
      after { set_rejected_at! }
      transitions from: :prepared, to: :review_failed
    end

    event :fail, before: :set_failure_reason do
      transitions to: :failed
    end

    event :fail_with_sync_option, before: :set_failure_reason do
      transitions from: [:preparing, :prepared, :failed_with_action_required, :finished_manually], to: :failed_with_action_required
    end

    event :finish_manually do
      transitions from: :failed_with_action_required, to: :finished_manually
    end
  end

  delegate :play_store_blocked?, to: :release_platform_run

  def change_build? = CHANGEABLE_STATES.include?(status) && editable?

  def cancellable? = false

  def finished?
    return true if finished_manually?
    FINAL_STATES.include?(status) && store_rollout.finished?
  end

  def pre_review? = PRE_PREPARE_STATES.include?(status) && editable?

  def reviewable? = false

  def requires_review? = false

  def version_bump_required? = false

  def triggerable?
    return false if play_store_blocked? && !internal_channel?
    super
  end

  def retryable?
    failed_with_action_required?
  end

  def internal_channel?
    submission_channel_id.to_sym == :internal
  end

  def trigger!
    return unless actionable?
    return start_prepare! if build_present_in_store?

    preprocess!
    StoreSubmissions::PlayStore::UploadJob.perform_later(id)
  end

  def retry!
    return unless retryable?

    if provider.build_present_in_channel?(submission_channel_id, build_number)
      transaction do
        finish_manually!
        event_stamp!(reason: :finished_manually, kind: :notice, data: stamp_data)
        release_platform_run.unblock_play_store_submissions!
      end

      if parent_release.production?
        on_prepare!
      else
        parent_release.rollout_complete!(self)
      end
    end
  end

  def upload_build!
    with_lock do
      return unless may_start_prepare?
      return fail_with_error!("Build not found") if build&.artifact.blank?

      build.artifact.with_open do |file|
        result = provider.upload(file)
        if result.ok?
          start_prepare!
        else
          fail_with_error!(result.error)
        end
      end
    end
  end

  def attach_build(build)
    return unless change_build?
    update(build:)
  end

  def retrigger!
    return unless created?

    reset_store_info!
    trigger!
  end

  def prepare_for_release!
    return mock_prepare_for_release_for_play_store! if sandbox_mode?

    result = provider.create_draft_release(submission_channel_id, build_number, version_name, notes, retry_on_review_fail: internal_channel?)
    if result.ok?
      finish_prepare!
      update_external_status
    else
      fail_with_error!(result.error)
    end
  end

  def provider = app.android_store_provider

  def update_external_status
    return if sandbox_mode?
    StoreSubmissions::PlayStore::UpdateExternalReleaseJob.perform_later(id)
  end

  def update_store_info!
    store_data = provider.find_build_in_track(submission_channel_id, build_number)
    return unless store_data
    self.store_release = store_data
    self.store_status = store_data[:status]
    self.store_link = provider.project_link
    save!
  end

  def notification_params
    super.merge(
      requires_review: false
    )
  end

  def fail_with_error!(error)
    elog(error)

    return if fail_with_review_rejected!(error)
    return fail!(reason: error.reason) if error.is_a?(Installations::Google::PlayDeveloper::Error)
    fail!
  end

  def fail_with_review_rejected!(error)
    if error.is_a?(Installations::Google::PlayDeveloper::Error) && error.reason == :app_review_rejected
      fail_with_sync_option!(reason: error.reason)
      release_platform_run.block_play_store_submissions!
      return true
    end

    false
  end

  private

  def on_start_prepare!
    StoreSubmissions::PlayStore::PrepareForReleaseJob.perform_later(id)
  end

  def tester_notes
    parent_release.tester_notes.truncate(MAX_NOTES_LENGTH)
  end

  def release_notes
    release_metadata.map do |metadatum|
      {
        language: metadatum.locale,
        text: metadatum.release_notes
      }
    end
  end

  def on_prepare!
    event_stamp!(reason: :prepared, kind: :notice, data: stamp_data)
    create_play_store_rollout!(
      release_platform_run:,
      config: conf.rollout_config.stages.presence || [],
      is_staged_rollout: staged_rollout?
    )
    play_store_rollout.start_release!(retry_on_review_fail: internal_channel?) if auto_rollout?
  end

  def build_present_in_store?
    return mock_build_present_in_play_store? if sandbox_mode?

    provider.find_build(build_number).present?
  end

  def stamp_data
    super.merge(track: submission_channel.name.humanize)
  end
end
