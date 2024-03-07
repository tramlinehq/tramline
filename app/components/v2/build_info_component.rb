class V2::BuildInfoComponent < V2::BaseComponent
  STATUS = {
    created: {text: "About to start", status: :inert},
    started: {text: "Running", status: :ongoing},
    preparing_release: {text: "Preparing store version", status: :ongoing},
    prepared_release: {text: "Ready for review", status: :ongoing},
    failed_prepare_release: {text: "Failed to start release", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    ready_to_release: {text: "Review approved", status: :ongoing},
    uploading: {text: "Uploading", status: :neutral},
    uploaded: {text: "Uploaded", status: :ongoing},
    rollout_started: {text: "Rollout started", status: :ongoing},
    released: {text: "Released", status: :success},
    failed: {text: "Failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure}
  }

  def initialize(deployment_run)
    @deployment_run = deployment_run
    @staged_rollout = deployment_run.staged_rollout
    @step_run = deployment_run.step_run
  end

  delegate :step, to: :@step_run
  delegate :deployment, :external_link, to: :@deployment_run

  def status
    return staged_rollout_status if @staged_rollout.present?
    STATUS[@deployment_run.status.to_sym] || {text: "Unknown", status: :neutral}
  end

  def staged_rollout_status
    percentage = ""

    if @staged_rollout.last_rollout_percentage.present?
      formatter = (@staged_rollout.last_rollout_percentage % 1 == 0) ? "%.0f" : "%.02f"
      percentage = formatter % @staged_rollout.last_rollout_percentage
    end

    case @staged_rollout.status.to_sym
    when :created
      {text: "Rollout started", status: :ongoing}
    when :started
      {text: "Rolled out to #{percentage}%", status: :ongoing}
    when :failed
      {text: "Failed to rollout out after #{percentage}%", status: :failure}
    when :completed
      {text: "Released", status: :success}
    when :stopped
      {text: "Rollout halted at #{percentage}%", status: :neutral}
    when :fully_released
      {text: "Released", status: :success}
    when :paused
      {text: "Rollout paused at #{percentage}%", status: :neutral}
    else
      {text: "Unknown", status: :neutral}
    end
  end

  def build_info
    "#{@step_run.build_version} (#{@step_run.build_number})"
  end

  def ci_info
    @step_run.commit.short_sha
  end

  def ci_link
    @step_run.ci_link
  end

  def build_deployed_at
    ago_in_words @deployment_run.updated_at
  end

  def last_activity_at
    last_updated_at = @staged_rollout&.updated_at || @deployment_run.updated_at
    time_format(last_updated_at)
  end

  def build_logo
    "integrations/logo_#{step.ci_cd_provider}.png"
  end

  def deployment_logo
    "integrations/logo_#{deployment.integration_type}.png"
  end
end
