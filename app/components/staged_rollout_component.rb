class StagedRolloutComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  HALT_CONFIRM = "You are about to halt the rollout of this build to production, it can not be resumed.\n\nAre you sure?"
  RELEASE_CONFIRM = "You are about to release this build to the next stage in production.\n\nAre you sure?"
  FULLY_RELEASE_CONFIRM = "You are about to release this build to all users in production.\n\nAre you sure?"

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
    :fully_released?,
    :config,
    :started?,
    :created?,
    :current_stage,
    :last_rollout_percentage,
    to: :staged_rollout
  delegate :controllable_rollout?, :rolloutable?, to: :deployment_run

  def release_actions(form)
    return unless controllable_rollout?
    return if stopped? || completed?

    if failed?
      retry_button(form)
    elsif started?
      increase_rollout_button(form)
    else
      start_rollout_button(form)
    end
  end

  def halt_action(form)
    return unless controllable_rollout?
    return unless last_rollout_percentage

    halt_rollout_button(form)
  end

  def fully_rollout_action(form)
    return unless rolloutable?
    return unless last_rollout_percentage

    fully_rollout_button(form)
  end

  def start_rollout_button(form)
    form.authz_submit :blue, "Start Rollout", class: "btn-xs"
  end

  def retry_button(form)
    form.authz_submit :blue, "Retry", class: "btn-xs"
  end

  def increase_rollout_button(form)
    form.authz_submit :blue, "Increase Rollout", class: "btn-xs"
  end

  def halt_rollout_button(form)
    form.authz_submit :red, "Halt", class: "btn-xs"
  end

  def fully_rollout_button(form)
    form.authz_submit :blue, "Release to 100%", class: "btn-xs"
  end

  def current_stage_perc
    return "0%" if last_rollout_percentage.nil?
    "#{last_rollout_percentage}%"
  end

  def stage_help
    return if completed? || fully_released?
    return "Halted at the #{current_stage.succ.ordinalize} stage of rollout" if stopped?

    if started?
      "In the #{current_stage.succ.ordinalize} stage of rollout"
    else
      "Rollout has not kicked-off yet"
    end
  end

  private

  delegate :writer?, to: :helpers
  attr_reader :release, :step_run, :deployment_run, :staged_rollout

  def release_form_url
    {
      model: [release, step_run, deployment_run, staged_rollout],
      url: increase_deployment_run_staged_rollout_path(deployment_run)
    }
  end

  def halt_form_url
    {
      model: [release, step_run, deployment_run, staged_rollout],
      url: halt_deployment_run_staged_rollout_path(deployment_run)
    }
  end

  def fully_release_form_url
    {
      model: [release, step_run, deployment_run, staged_rollout],
      url: fully_release_deployment_run_staged_rollout_path(deployment_run)
    }
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
      else
        ["Unknown", :neutral]
      end

    status_badge(status, styles)
  end
end
