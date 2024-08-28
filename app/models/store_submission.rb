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
class StoreSubmission < ApplicationRecord
  # include Sandboxable
  include AASM
  include Passportable
  include Loggable

  has_one :store_rollout, dependent: :destroy
  belongs_to :release_platform_run
  belongs_to :parent_release, polymorphic: true
  # rubocop:disable Rails/InverseOf
  belongs_to :production_release, -> { where(store_submissions: {parent_release_type: "ProductionRelease"}) }, foreign_key: "parent_release_id", optional: true
  # rubocop:enable Rails/InverseOf
  belongs_to :build

  delegate :release_metadata, :train, :release, :app, :platform, to: :release_platform_run
  delegate :project_link, :public_icon_img, to: :provider, allow_nil: true
  delegate :notify!, to: :train
  delegate :version_name, :build_number, to: :build
  delegate :actionable?, to: :parent_release

  scope :production, -> { where(parent_release_type: "ProductionRelease") }

  def submission_channel
    conf.submission_config
  end

  def triggerable?
    created? && actionable?
  end

  def editable?
    parent_release.production? && parent_release.inflight? && actionable?
  end

  def submission_channel_id
    conf.submission_config.id.to_s
  end

  def staged_rollout?
    conf.rollout_config.enabled
  end

  def auto_rollout? = !parent_release.production?

  def external_link
    store_link || project_link
  end

  def pre_review? = true

  def change_build? = raise NotImplementedError

  def reviewable? = raise NotImplementedError

  def cancellable? = raise NotImplementedError

  def retryable? = false

  def failed_with_action_required? = false

  def version_bump_required? = raise NotImplementedError

  def attach_build(_build)
    raise NotImplementedError
  end

  def self.create_and_trigger!(parent_release, submission_config, build)
    auto_promote = submission_config.auto_promote?
    auto_promote = parent_release.conf.auto_promote? if auto_promote.nil?
    release_platform_run = parent_release.release_platform_run
    sequence_number = submission_config.number
    config = submission_config.to_h

    submission = create!(parent_release:, release_platform_run:, build:, sequence_number:, config:)
    submission.trigger! if auto_promote
  end

  def notification_params
    parent_release.notification_params.merge(
      submission_failure_reason: (display_attr(:failure_reason) if failure_reason.present?)
    )
  end

  def review_time
    approved_at.to_i - submitted_at.to_i
  end

  def fail_with_error!(error)
    elog(error)
    if error.is_a?(Installations::Error)
      fail!(reason: error.reason)
    else
      fail!
    end
  end

  def notes
    if parent_release.release_notes?
      release_notes
    elsif parent_release.tester_notes?
      tester_notes
    end
  end

  def tester_notes
    raise NotImplementedError
  end

  def release_notes
    raise NotImplementedError
  end

  protected

  def reset_store_info!
    self.store_release = nil
    self.store_status = nil
    self.store_link = nil
    save!
  end

  def set_failure_reason(args = nil)
    self.failure_reason = args&.fetch(:reason, :unknown_failure)
  end

  def set_prepared_at!
    update! prepared_at: Time.current
  end

  def set_submitted_at!
    update! submitted_at: Time.current
  end

  def set_approved_at!
    update! approved_at: Time.current
  end

  def set_rejected_at!
    update! rejected_at: Time.current
  end

  def stamp_data
    {
      version: version_name,
      build_number: build_number,
      failure_reason: (display_attr(:failure_reason) if failure_reason.present?)
    }
  end

  def conf = ReleaseConfig::Platform::Submission.new(config)
end
