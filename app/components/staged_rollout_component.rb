class StagedRolloutComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  HALT_CONFIRM = "You are about to halt the rollout of this build to production, it can not be resumed.\n\nAre you sure?"
  RELEASE_CONFIRM = "You are about to release this build to production.\n\nAre you sure?"

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
    :roll_out_started?,
    :current_stage,
    :last_rollout_percentage,
    to: :staged_rollout
  delegate :writer?, to: :helpers

  def release_actions(form)
    return if stopped? || completed?

    if failed?
      retry_button(form)
    elsif current_stage.present?
      increase_rollout_button(form)
    else
      start_rollout_button(form)
    end
  end

  def halt_action(form)
    return unless roll_out_started?
    halt_rollout_button(form)
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

  def until_current?(stage)
    return false if current_stage.nil?
    current_stage >= stage
  end

  def current_stage_perc
    stage_perc(last_rollout_percentage)
  end

  def stage_perc(stage)
    return "0%" if stage.nil?
    "#{stage}%"
  end

  def stage_help
    return if completed?
    return "Halted at the #{current_stage.succ.ordinalize} stage of rollout" if stopped?

    if current_stage
      "In the #{current_stage.succ.ordinalize} stage of rollout"
    else
      "Rollout has not kicked-off yet"
    end
  end

  private

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

  def badge
    status = staged_rollout.status.to_sym
    return if status.eql?(:started) && current_stage.nil?

    status, styles =
      case status
      when :started
        ["Active", STATUS_COLOR_PALETTE[:ongoing]]
      when :failed
        ["Failed", STATUS_COLOR_PALETTE[:failure]]
      when :completed
        ["Completed", STATUS_COLOR_PALETTE[:success]]
      when :stopped
        ["Halted", STATUS_COLOR_PALETTE[:inert]]
      else
        ["Unknown", STATUS_COLOR_PALETTE[:neutral]]
      end

    status_badge(status, styles)
  end
end
