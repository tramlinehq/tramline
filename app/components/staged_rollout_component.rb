class StagedRolloutComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  HALT_CONFIRM = "You are about to halt the rollout of this build to production, it can not be resumed.\n\nAre you sure?"
  START_RELEASE_CONFIRM = "You are about to release this build to the first stage in production.\n\nAre you sure?"
  RELEASE_CONFIRM = "You are about to release this build to the next stage in production.\n\nAre you sure?"
  FULLY_RELEASE_CONFIRM = "You are about to release this build to all users in production.\n\nAre you sure?"
  PAUSE_RELEASE_CONFIRM = "You are about to pause the scheduled phased release in production.\n\nAre you sure?"
  RESUME_RELEASE_CONFIRM = "You are about to resume the scheduled phased release in production.\n\nAre you sure?"

  def initialize(staged_rollout)
    @staged_rollout = staged_rollout
    @deployment_run = @staged_rollout.deployment_run
    @step_run = @deployment_run.step_run
    @release = @step_run.train_run
  end

  delegate :started?,
    :failed?,
    :stopped?,
    :completed?,
    :paused?,
    :fully_released?,
    :config,
    :started?,
    :created?,
    :current_stage,
    :last_rollout_percentage,
    to: :staged_rollout
  delegate :controllable_rollout?, :rolloutable?, :automatic_rollout?, to: :deployment_run

  def actions
    actions = []

    if controllable_rollout?
      actions << {form_url: increase_release_path, confirm: START_RELEASE_CONFIRM, type: :blue, name: "Start Rollout"} if created?
      actions << {form_url: increase_release_path, confirm: RELEASE_CONFIRM, type: :blue, name: "Increase Rollout"} if started?
      actions << {form_url: increase_release_path, confirm: RELEASE_CONFIRM, type: :blue, name: "Retry"} if failed?
    end

    if automatic_rollout?
      actions << {form_url: resume_release_path, confirm: RESUME_RELEASE_CONFIRM, type: :blue, name: "Resume Phased Release"} if paused?
      actions << {form_url: pause_release_path, confirm: PAUSE_RELEASE_CONFIRM, type: :amber, name: "Pause Phased Release"} if started? && last_rollout_percentage
    end

    if last_rollout_percentage
      actions << {form_url: halt_release_path, confirm: HALT_CONFIRM, type: :red, name: "Halt Release"} if started? || paused?
      actions << {form_url: full_release_path, confirm: FULLY_RELEASE_CONFIRM, type: :blue, name: "Release to 100%"} if started?
    end

    actions
  end

  def current_stage_perc
    return "0%" if last_rollout_percentage.nil?
    "#{last_rollout_percentage}%"
  end

  def stage_help
    return if completed? || fully_released?
    return "Halted at the #{current_stage.succ.ordinalize} stage of rollout" if stopped?
    return "Paused at the #{current_stage.succ.ordinalize} stage of rollout" if paused?

    if started?
      "In the #{current_stage.succ.ordinalize} stage of rollout"
    else
      "Rollout has not kicked-off yet"
    end
  end

  private

  delegate :writer?, to: :helpers
  attr_reader :release, :step_run, :deployment_run, :staged_rollout

  def increase_release_path
    increase_deployment_run_staged_rollout_path(deployment_run)
  end

  def halt_release_path
    halt_deployment_run_staged_rollout_path(deployment_run)
  end

  def pause_release_path
    pause_deployment_run_staged_rollout_path(deployment_run)
  end

  def resume_release_path
    resume_deployment_run_staged_rollout_path(deployment_run)
  end

  def full_release_path
    fully_release_deployment_run_staged_rollout_path(deployment_run)
  end

  def badge
    status = staged_rollout.status.to_sym

    status, styles =
      case status
      when :created
        ["Ready", :routine]
      when :started
        ["Active", :ongoing]
      when :failed
        ["Failed", :failure]
      when :completed
        ["Completed", :success]
      when :stopped
        ["Halted", :inert]
      when :fully_released
        ["Released to all users", :success]
      when :paused
        ["Paused phased release", :ongoing]
      else
        ["Unknown", :neutral]
      end

    status_badge(status, styles)
  end
end
