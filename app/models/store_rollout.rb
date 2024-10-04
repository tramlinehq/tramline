# == Schema Information
#
# Table name: store_rollouts
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  config                  :decimal(8, 5)    default([]), not null, is an Array
#  current_stage           :integer
#  is_staged_rollout       :boolean          default(FALSE)
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#  store_submission_id     :uuid             indexed
#
class StoreRollout < ApplicationRecord
  using RefinedString
  include AASM
  include Loggable
  include Displayable
  # include Sandboxable

  belongs_to :store_submission
  belongs_to :release_platform_run

  delegate :train, to: :release_platform_run
  delegate :notify!, to: :train

  STAMPABLE_REASONS = %w[
    started
    paused
    resumed
    increased
    completed
    halted
    fully_released
  ]
  STATES = {
    created: "created",
    started: "started",
    paused: "paused",
    completed: "completed",
    halted: "halted",
    fully_released: "fully_released"
  }

  enum :status, STATES

  delegate :parent_release, :build, :external_link, to: :store_submission
  delegate :version_name, :build_number, to: :build
  delegate :train, :platform, to: :release_platform_run
  delegate :notify!, to: :train

  scope :production, -> { joins(store_submission: :production_release) }

  def staged_rollout? = is_staged_rollout

  def errors? = errors.any?

  def provider = release_platform_run.store_provider

  def finished? = completed? || fully_released?

  def reached_last_stage? = next_rollout_percentage.nil?

  delegate :stale?, :actionable?, to: :parent_release

  def stage
    (current_stage || 0).succ
  end

  def next_rollout_percentage
    return config.first if created?
    config[next_stage]
  end

  def last_rollout_percentage
    return Release::FULL_ROLLOUT_VALUE if finished? && !staged_rollout?
    return Release::FULL_ROLLOUT_VALUE if fully_released?
    return 0 if created? || current_stage.nil?
    return config.last if reached_last_stage?
    config[current_stage]
  end

  def latest_events(n = nil)
    passports.order(created_at: :desc).limit(n)
  end

  def notification_params
    store_submission.notification_params.merge(stamp_data)
  end

  def rollout_percentage_at(day)
    last_event = passports
      .where(reason: [:started, :increased, :fully_released])
      .where("DATE_TRUNC('day', event_timestamp) <= ?", day)
      .order(:event_timestamp)
      .last
    return 0.0 unless last_event
    return 100.0 if last_event.reason == "fully_released"
    last_event.metadata["rollout_percentage"].safe_float
  end

  protected

  def next_stage
    current_stage.blank? ? 0 : current_stage.succ
  end

  def update_stage(stage, finish_rollout: false)
    return if stage == current_stage && !finish_rollout

    update!(current_stage: stage)
    if may_start?
      start!
      event_stamp!(reason: :started, kind: :success, data: stamp_data)
    else
      event_stamp!(reason: :updated, kind: :notice, data: stamp_data)
      notify!("Rollout has been updated", :production_rollout_updated, notification_params)
    end

    if finish_rollout && reached_last_stage?
      complete!
      event_stamp!(reason: :completed, kind: :success, data: stamp_data)
    end
  end

  def stamp_data
    data = {
      current_stage: stage,
      version: version_name,
      build_number: build_number
    }

    data[:rollout_percentage] =
      if is_staged_rollout? && current_stage.present?
        "%.2f" % config[current_stage]
      else
        "100"
      end

    data
  end

  def on_start!
    parent_release.rollout_started!
  end

  def on_complete!
    parent_release.rollout_complete!(store_submission)
  end

  def set_completed_at!
    update! completed_at: Time.current
  end
end
