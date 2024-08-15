# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  config                  :jsonb            not null
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
#  parent_release_id       :uuid             not null, indexed => [parent_release_type]
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
  ]

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
  CHANGEABLE_STATES = %w[created preprocessing failed prepared]

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

    # TODO: [V2] This is currently not used, should be hooked up as an action from the user
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

  def change_build? = CHANGEABLE_STATES.include?(status) && editable?

  def cancellable? = false

  def finished? = FINAL_STATES.include?(status) # TODO: [V2] can we use another proxy and remove this method. is currently used in view only.

  def reviewable? = false

  def requires_review? = false

  def trigger!
    return unless actionable?
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
    return unless change_build?
    update(build:)
  end

  def retrigger!
    return unless created?

    # reset_store_info! # TODO: [V2] implement this
    trigger!
  end

  def prepare_for_release!
    return mock_prepare_for_release_for_play_store! if sandbox_mode?

    result = provider.create_draft_release(deployment_channel_id, build_number, version_name, release_notes)
    if result.ok?
      finish_prepare!
      update_external_status
    else
      fail_with_error(result.error)
    end
  end

  def provider = app.android_store_provider

  def update_external_status
    return if sandbox_mode?
    StoreSubmissions::PlayStore::UpdateExternalReleaseJob.perform_later(id)
  end

  def update_store_info!
    store_data = provider.find_build_in_track(deployment_channel_id, build_number)
    return unless store_data
    self.store_release = store_data
    self.store_status = store_data[:status]
    self.store_link = provider.project_link
    save!
  end

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
    event_stamp!(reason: :prepared, kind: :notice, data: stamp_data)
    create_play_store_rollout!(
      release_platform_run:,
      config: conf.rollout_config.stages.presence || [],
      is_staged_rollout: staged_rollout?
    )
    play_store_rollout.start_release! if auto_rollout?
  end

  def build_present_in_store?
    return mock_build_present_in_play_store? if sandbox_mode?

    provider.find_build(build_number).present?
  end

  def stamp_data
    super.merge(track: deployment_channel.name.humanize)
  end
end
