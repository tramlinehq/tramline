# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
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
#  submission_config       :jsonb
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  parent_release_id       :bigint           not null, indexed => [parent_release_type]
#  release_platform_run_id :uuid             not null, indexed
class GoogleFirebaseSubmission < StoreSubmission
  STATES = {
    created: "created",
    preprocessing: "preprocessing",
    preparing: "preparing",
    finished: "finished",
    failed: "failed",
    failed_with_action_required: "failed_with_action_required"
  }
  FINAL_STATES = %w[finished]

  enum status: STATES
  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :preprocess do
      transitions from: :created, to: :preprocessing
    end

    event :prepare, after_commit: :on_prepare! do
      transitions from: [:created, :preprocessing, :failed], to: :preparing
    end

    event :finish do
      after { set_prepared_at! }
      transitions to: :finished
    end

    event :fail, before: :set_failure_reason do
      transitions to: :failed
    end

    event :fail_with_sync_option, before: :set_failure_reason do
      transitions from: [:prepared, :failed_with_action_required], to: :failed_with_action_required
    end
  end

  def change_allowed? = true

  def locked? = false

  def reviewable? = false

  def requires_review? = false

  def cancellable? = false

  def integration_type = :google_firebase

  def finished?
    status.in? FINAL_STATES
  end

  def trigger!
    return unless may_prepare?

    if build_present_in_store?
      prepare_and_update!(@build)
      return
    end

    preprocess!
    StoreSubmissions::GoogleFirebase::UploadJob.perform_later(id)
  end

  def upload_build!
    return unless may_prepare?
    return fail_with_error("Build not found") if build&.artifact.blank?

    result = nil
    filename = build_artifact.file.filename.to_s
    build_artifact.with_open do |file|
      result = provider.upload(file, filename, platform:, variant: step_run.app_variant)
      unless result.ok?
        fail_with_error(result.error)
      end
    end

    StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob.perform_later(id, result.value!) if result&.ok?
  end

  def prepare_for_release!
    return unless may_finish?

    # FIXME: get deployment_channel from somewhere
    deployment_channels = ["group-1-id", "group-2-id"]
    result = provider.release(run.external_release.external_id, deployment_channels)
    if result.ok?
      finish!
    else
      fail_with_error(result.error)
    end
  end

  def update_upload_status!(op_name)
    return unless may_prepare?
    result = provider.get_upload_status(op_name)
    unless result.ok?
      fail_with_error(result.error)
      return
    end

    release_info = result.value!
    raise UploadNotComplete unless release_info.done?

    prepare_and_update!(release_info)
    StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob.perform_later(id, release_info.release)
  end

  # FIXME: get notes from somewhere
  def update_build_notes!(release_name)
    provider.update_release_notes(release_name, "NOTES")
  end

  def send_notes?
    false
  end

  private

  def prepare_and_update!(release_info)
    transaction do
      prepare!
      update_store_info!(release_info)
    end
  end

  def on_prepare!
    StoreSubmissions::GoogleFirebase::PrepareForReleaseJob.perform_later(id)
  end

  def update_store_info!(release_info)
    self.store_link = release_info.console_link
    self.store_status = release_info.status
    self.store_release = release_info.release_info
    save!
  end

  def find_build
    @build ||= provider.find_build_by_build_number(build_number, release_platform_run.platform)
  end

  def build_present_in_store?
    find_build.ok?
  end
end
