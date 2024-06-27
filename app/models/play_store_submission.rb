# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  deployment_channel      :jsonb
#  failure_reason          :string
#  name                    :string
#  parent_release_type     :string           not null, indexed => [parent_release_id]
#  prepared_at             :datetime
#  rejected_at             :datetime
#  sequence_number         :integer          default(0), not null
#  status                  :string           not null
#  store_link              :string
#  store_release           :jsonb
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
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

  STATES = STATES.merge(
    failed_with_action_required: "failed_with_action_required"
  )
  FINAL_STATES = %w[prepared]

  enum failure_reason: {
    unknown_failure: "unknown_failure"
  }.merge(Installations::Google::PlayDeveloper::Error.reasons.zip_map_self)
  enum status: STATES

  # Things that have happened before Store Submission
  # 1. Build has been created and uploaded to App Bundle Explorer
  # 2. Build has sent for alpha and beta testing (optionally)
  # 3. Beta soak has ended (if configured)
  # 4. Release metadata has been updated
  #
  # Things that will happen during Store Submission
  # 1. Prepare for release
  # 4. Reject
  #
  # Things that will happen after Store Submission
  # 1. Rollout (staged or otherwise)
  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start_prepare, guard: :startable?, after: :on_start_prepare! do
      transitions from: [:created, :prepared, :failed], to: :preparing
    end

    event :finish_prepare, after_commit: :on_prepare! do
      after { set_prepared_at! }
      transitions from: :preparing, to: :prepared
    end

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

  def change_allowed? = true

  def locked? = false # TODO: This should be false once rollout starts

  def reviewable? = false

  def requires_review? = false

  def cancellable? = false

  def finished?
    status.in? FINAL_STATES
  end

  def integration_type = :google_play_store

  def on_start_prepare!
    StoreSubmissions::PlayStore::PrepareForReleaseJob.perform_later(id)
  end

  def prepare_for_release!
    return unless startable?

    result = provider.create_draft_release(deployment_channel_id, build_number, version_name, release_notes)
    if result.ok?
      finish_prepare!
    else
      fail_with_error(result.error)
    end
  end

  def release_notes
    [{
      language: release_metadatum.locale,
      text: release_metadatum.release_notes
    }]
  end

  def deployment_channel_id
    deployment_channel["id"].to_s
  end

  def on_prepare!
    create_play_store_rollout!(release_platform_run:)
  end
end
