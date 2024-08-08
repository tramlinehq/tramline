# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  config                  :jsonb
#  failure_reason          :string
#  name                    :string
#  parent_release_type     :string           not null, indexed => [parent_release_id]
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
#  parent_release_id       :bigint           not null, indexed => [parent_release_type]
#  release_platform_run_id :uuid             not null, indexed
#
class PlayStoreSubmission < StoreSubmission
  using RefinedArray
  using RefinedString

  has_one :play_store_rollout,
    foreign_key: :store_submission_id,
    dependent: :destroy,
    inverse_of: :play_store_submission

  STATES = {
    created: "created",
    preprocessing: "preprocessing",
    preparing: "preparing",
    prepared: "prepared",
    review_failed: "review_failed",
    failed: "failed",
    failed_with_action_required: "failed_with_action_required"
  }
  FINAL_STATES = %w[prepared]
  CHANGEABLE_STATES = %w[created preprocessing failed]

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
      after { set_prepared_at! }
      transitions from: :preparing, to: :prepared
    end

    # TODO: This is currently not used, should be hooked up as an action from the user
    event :reject do
      after { set_rejected_at! }
      transitions from: :prepared, to: :review_failed
    end

    event :fail, before: :set_failure_reason do
      transitions to: :failed
    end

    event :fail_with_sync_option, before: :set_failure_reason do
      transitions from: [:preparing, :prepared, :failed_with_action_required], to: :failed_with_action_required
    end
  end

  def change_allowed? = CHANGEABLE_STATES.include?(status) && !locked? && active_release?

  def cancellable? = false

  def finished? = FINAL_STATES.include?(status)

  def locked? = play_store_rollout&.started?

  def reviewable? = false

  def requires_review? = false

  def trigger!
    return unless parent_release.active?
    return start_prepare! if build_present_in_store?

    preprocess!
    StoreSubmissions::PlayStore::UploadJob.perform_later(id)
  end

  def upload_build!
    with_lock do
      return unless may_start_prepare?
      return fail_with_error("Build not found") if build&.artifact.blank?

      build.artifact.with_open do |file|
        result = provider.upload(file)
        if result.ok?
          start_prepare!
        else
          fail_with_error(result.error)
        end
      end
    end
  end

  def attach_build(build)
    return unless change_allowed?

    update(build:)
    trigger! unless created?
    true
  end

  def prepare_for_release!
    result = provider.create_draft_release(deployment_channel_id, build_number, version_name, release_notes)
    if result.ok?
      finish_prepare!
    else
      fail_with_error(result.error)
    end
  end

  def provider = app.android_store_provider

  private

  def on_start_prepare!
    StoreSubmissions::PlayStore::PrepareForReleaseJob.perform_later(id)
  end

  # TODO: implement build notes choice
  def release_notes
    [{
      language: release_metadatum.locale,
      text: release_metadatum.release_notes
    }]
  end

  def on_prepare!
    create_play_store_rollout!(
      release_platform_run:,
      config: conf.rollout_config.stages.presence || [],
      is_staged_rollout: staged_rollout?
    )
    play_store_rollout.start_release! if auto_rollout?
  end

  def build_present_in_store?
    provider.find_build(build_number).present?
  end
end
