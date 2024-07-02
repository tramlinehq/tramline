class FirebaseSubmission < StoreSubmission
  STATES = {
    created: "created",
    prepared: "prepared",
    failed: "failed",
    failed_with_action_required: "failed_with_action_required"
  }
  FINAL_STATES = %w[prepared]

  # created, and start uploading
  # if already uploaded, start preparing to send to groups
  # if not already uploaded, keep in created, start tracking uploading
  # once, uploaded, start preparing

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start_prepare, guard: :startable?, after: :on_start_prepare! do
      transitions from: [:created, :failed], to: :preparing
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
    return unless may_start_prepare?
    return start_prepare! if build_present_in_store?
    StoreSubmissions::GoogleFirebase::UploadJob.perform_later(id)
  end

  def upload_build!
    return unless may_start_prepare?
    return fail_with_error("Build not found") if build&.artifact.blank?

    result = nil
    run.build_artifact.with_open do |file|
      result = provider.upload(file, run.build_artifact.file.filename.to_s, platform:, variant: step_run.app_variant)
      unless result.ok?
        run.fail_with_error(result.error)
      end
    end

    StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob.perform_later(id, result.value!) if result&.ok?
  end

  def prepare_for_release!
    return unless may_finish?

    # FIXME: get deployment_channel from somewhere
    deployment_channel = ["group-1-id", "group-2-id"]
    result = provider.release(run.external_release.external_id, deployment_channel)
    if result.ok?
      finish!
    else
      fail_with_error(result.error)
    end
  end

  def update_upload_status!(op_name)
    return unless may_start_prepare?
    result = provider.get_upload_status(op_name)
    unless result.ok?
      fail_with_error(result.error)
      return
    end

    release_info = result.value!
    raise UploadNotComplete unless release_info.done?

    transaction do
      start_prepare!
      update_store_info!(release_info)
    end

    StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob.perform_later(id, release_info.release)
  end

  # FIXME: get notes from somewhere
  def update_build_notes!(release_name)
    provider.update_release_notes(release_name, "NOTES")
  end

  private

  def on_start_prepare!
    StoreSubmissions::GoogleFirebase::PrepareForReleaseJob.perform_later(id)
  end

  def update_store_info!(release_info)
    self.store_link = release_info.console_link
    self.store_status = release_info.status
    self.store_release = release_info.release_info
    save!
  end

  def build_present_in_store?
    provider.find_build(build_number).present?
  end
end

# TODO:
# - state transition checks in jobs
#
