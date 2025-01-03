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
  has_paper_trail
  # include Sandboxable
  include AASM
  include Passportable
  include Loggable

  BuildNotFound = Installations::Error.new("Build not found", reason: :build_not_found)

  has_one :store_rollout, dependent: :destroy
  belongs_to :release_platform_run
  belongs_to :parent_release, polymorphic: true
  # rubocop:disable Rails/InverseOf
  belongs_to :production_release, -> { where(store_submissions: {parent_release_type: "ProductionRelease"}) }, foreign_key: "parent_release_id", optional: true
  # rubocop:enable Rails/InverseOf
  belongs_to :build

  delegate :release_metadata, :train, :release, :app, :platform, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :version_name, :build_number, to: :build
  delegate :actionable?, to: :parent_release

  scope :sequential, -> { reorder("store_submissions.sequence_number ASC") }
  scope :production, -> { where(parent_release_type: "ProductionRelease") }

  # TODO: Remove this accessor, once the migration is complete
  attr_accessor :in_data_migration_mode

  def submission_channel
    conf.submission_external
  end

  def triggerable?
    created? && actionable?
  end

  def editable?
    parent_release.production? && parent_release.inflight? && actionable?
  end

  def submission_channel_id
    conf.submission_external.identifier.to_s
  end

  def staged_rollout?
    conf.rollout_enabled?
  end

  def auto_rollout? = !parent_release.production?

  def external_link
    store_link || provider&.project_link
  end

  def pre_review? = true

  def change_build? = raise NotImplementedError

  def reviewable? = raise NotImplementedError

  def cancellable? = raise NotImplementedError

  def cancelling? = raise NotImplementedError

  def post_review? = raise NotImplementedError

  def retryable? = false

  def failed_with_action_required? = false

  def attach_build(_build)
    raise NotImplementedError
  end

  def self.create_and_trigger!(parent_release, submission_config, build)
    auto_promote = submission_config.auto_promote?
    auto_promote = parent_release.conf.auto_promote? if auto_promote.nil?
    release_platform_run = parent_release.release_platform_run
    sequence_number = submission_config.number
    config = submission_config.as_json

    submission = create!(parent_release:, release_platform_run:, build:, sequence_number:, config:)
    submission.trigger! if auto_promote
  end

  def notification_params(failure_message: nil, requires_manual_action: false)
    parent_release.notification_params.merge(
      submission_failure_reason: (get_failure_message(failure_message) if failure_reason.present?),
      submission_asset_link: provider&.public_icon_img,
      project_link: external_link,
      deep_link: deep_link,
      submission_requires_manual_action: requires_manual_action
    )
  end

  def review_time
    approved_at.to_i - submitted_at.to_i
  end

  def fail_with_error!(error)
    elog(error)
    if error.is_a?(Installations::Error)
      fail!(reason: error.reason, error: error)
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

  def deep_link
    nil
  end

  def finish_rollout_in_next_release?
    false
  end

  def conf = Config::Submission.from_json(config, read_only: true)

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

  def stamp_data(failure_message: nil)
    {
      version: version_name,
      build_number: build_number,
      failure_reason: (get_failure_message(failure_message) if failure_reason.present?)
    }
  end

  def get_failure_message(default_message = nil)
    if failure_reason.present? && failure_reason != self.class.failure_reasons[:unknown_failure]
      display_attr(:failure_reason)
    else
      default_message || self.class.human_attr_value(:failure_reason, :unknown_failure)
    end
  end
end
