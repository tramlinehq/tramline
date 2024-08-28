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
class TestFlightSubmission < StoreSubmission
  STAMPABLE_REASONS = %w[
    triggered
    submitted_for_review
    review_rejected
    finished
    failed
  ]
  STATES = {
    created: "created",
    preprocessing: "preprocessing",
    submitting_for_review: "submitting_for_review",
    submitted_for_review: "submitted_for_review",
    review_failed: "review_failed",
    finished: "finished",
    failed: "failed"
  }

  NOTES_MAX_LENGTH = 4000

  SubmissionNotInTerminalState = Class.new(StandardError)

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :preprocess do
      transitions from: :created, to: :preprocessing
    end

    event :submit_for_review, after_commit: :on_submit_for_review! do
      after { set_submitted_at! }
      transitions from: [:created, :preprocessing], to: :submitted_for_review
    end

    event :reject, after_commit: :on_reject! do
      after { set_rejected_at! }
      transitions from: :submitted_for_review, to: :review_failed
    end

    event :fail, before: :set_failure_reason, after_commit: :on_fail! do
      transitions to: :failed
    end

    event :finish, after_commit: :on_finish! do
      after { set_approved_at! }
      transitions from: [:created, :preprocessing, :submitted_for_review], to: :finished
    end
  end

  def internal_channel?
    submission_channel.is_internal
  end

  def trigger!
    return unless actionable?

    event_stamp!(reason: :triggered, kind: :notice, data: stamp_data)
    return mock_start_release_in_testflight if sandbox_mode?
    return start_release! if build_present_in_store?

    preprocess!
    StoreSubmissions::TestFlight::FindBuildJob.perform_async(id)
  end

  def start_release!
    return unless may_submit_for_review?

    update_build_notes!

    if internal_channel?
      release_info = find_build.value!
      update_store_info!(release_info)
      return finish!
    end

    result = provider.release_to_testflight(submission_channel_id, build_number)
    return fail_with_error!(result.error) unless result.ok?

    submit_for_review!
  end

  def update_build_notes!
    provider.update_release_notes(build_number, notes)
  end

  def on_submit_for_review!
    event_stamp!(reason: :submitted_for_review, kind: :notice, data: stamp_data)
    StoreSubmissions::TestFlight::UpdateExternalBuildJob.perform_async(id)
  end

  def update_external_release
    result = find_build

    unless result.ok?
      elog(result.error)
      raise SubmissionNotInTerminalState, "Retrying in some time..."
    end

    release_info = result.value!
    update_store_info!(release_info)

    if release_info.success?
      finish!
    elsif release_info.review_failed?
      reject!
    else
      raise SubmissionNotInTerminalState, "Retrying in some time..."
    end
  end

  def find_build
    @build ||= provider.find_build(build_number)
  end

  def provider = app.ios_store_provider

  private

  def tester_notes
    parent_release.tester_notes.truncate(NOTES_MAX_LENGTH)
  end

  def release_notes
    release_platform_run.default_release_metadata&.release_notes&.truncate(NOTES_MAX_LENGTH)
  end

  def build_present_in_store?
    find_build.ok?
  end

  def update_store_info!(release_info)
    self.store_release = release_info.build_info
    self.store_status = release_info.attributes[:status]
    self.store_link = release_info.attributes[:external_link]
    save!
  end

  def on_reject!
    event_stamp!(reason: :review_rejected, kind: :error, data: stamp_data)
  end

  def on_fail!
    event_stamp!(reason: :failed, kind: :error, data: stamp_data)
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: stamp_data)
    parent_release.rollout_complete!(self)
  end

  def stamp_data
    super.merge(channels: submission_channel.name)
  end
end
