class StoreRolloutPresenter < SimpleDelegator
  STATUS = {
    created: {text: "Ready", status: :routine},
    started: {text: "Active", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    completed: {text: "Completed", status: :success},
    halted: {text: "Halted", status: :inert},
    fully_released: {text: "Released to all users", status: :success},
    paused: {text: "Paused phased release", status: :ongoing}
  }

  def initialize(rollout, view_context = nil)
    @view_context = view_context
    super(rollout)
  end

  def upcoming? = created?

  def decorated_status
    h.status_picker(STATUS, status)
  end

  def full_rollout_status
    percentage = ""

    if last_rollout_percentage.present?
      formatter = (last_rollout_percentage % 1 == 0) ? "%.0f" : "%.02f"
      percentage = formatter % last_rollout_percentage
    end

    case status.to_sym
    when :created
      {text: "Rollout started", status: :ongoing}
    when :started
      {text: "Rolled out to #{percentage}%", status: :ongoing}
    when :failed
      {text: "Failed to rollout out after #{percentage}%", status: :failure}
    when :completed
      {text: "Released", status: :success}
    when :stopped
      {text: "Rollout halted at #{percentage}%", status: :inert}
    when :fully_released
      {text: "Released", status: :success}
    when :paused
      {text: "Rollout paused at #{percentage}%", status: :neutral}
    else
      {text: "Unknown", status: :neutral}
    end
  end

  def store_icon
    "integrations/logo_#{provider}.png"
  end

  def last_activity_at
    h.ago_in_words(updated_at)
  end

  def last_activity_tooltip
    "Last activity at #{h.time_format(updated_at)}"
  end

  def h
    @view_context
  end
end
