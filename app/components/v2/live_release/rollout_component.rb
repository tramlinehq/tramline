class V2::LiveRelease::RolloutComponent < V2::BaseComponent
  STATUS = {
    created: {text: "Ready", status: :routine},
    started: {text: "Active", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    completed: {text: "Completed", status: :success},
    halted: {text: "Halted", status: :inert},
    fully_released: {text: "Released to all users", status: :success},
    paused: {text: "Paused phased release", status: :ongoing}
  }

  def initialize(store_rollout, compact: false)
    @store_rollout = store_rollout
    @compact = compact
  end

  attr_reader :store_rollout
  delegate :release_platform_run, :build, :provider, :last_rollout_percentage, :stage, :automatic_rollout?, :controllable_rollout?, :id, to: :store_rollout
  delegate :platform, :release, to: :release_platform_run

  def compact?
    @compact
  end

  def monitoring_size
    release_platform_run.app.cross_platform? ? :compact : :default
  end

  def events
    [{
      timestamp: time_format(1.day.ago, with_year: false),
      title: "Rollout increase",
      description: "The staged rollout for this release has been increased to 50%",
      type: :success
    },
      {
        timestamp: time_format(2.days.ago, with_year: false),
        title: "Rollout increase",
        description: "The staged rollout for this release has been increased to 20%",
        type: :success
      },
      {
        timestamp: time_format(3.days.ago, with_year: false),
        title: "Rollout increase",
        description: "The staged rollout for this release has been increased to 10%",
        type: :success
      },
      {
        timestamp: time_format(4.days.ago, with_year: false),
        title: "Rollout increase",
        description: "The staged rollout for this release has been increased to 1%",
        type: :success
      }]
  end

  def status
    STATUS[store_rollout.status.to_sym] || {text: store_rollout.status.humanize, status: :neutral}
  end

  def stage_help
    "at #{stage.ordinalize} stage"
  end

  def action_help
    case store_rollout.status.to_sym
    when :created
      "Start the rollout to initiate your staged rollout sequence."
    when :started
      "Increase the rollout to move to the next stage of your rollout sequence."
    when :paused
      "Resume rollout to continue your rollout sequence."
    when :halted
      "Resume rollout to continue your rollout sequence."
    when :completed
      "The rollout has been completed."
    when :fully_released
      "The rollout has been fully released to all users."
    else
      raise "Invalid status: #{store_rollout.status}"
    end
  end

  def stages
    store_rollout.config.map do |stage_percentage|
      [stage_percentage, (stage_percentage > last_rollout_percentage) ? :inert : :default]
    end
  end

  def action
    return if compact?
    return if store_rollout.completed? || store_rollout.fully_released? || store_rollout.halted?

    return action_button("Start rollout", start_release_platform_store_rollout_path(release, platform, id)) if store_rollout.created?
    action_button("Increase rollout", increase_release_platform_store_rollout_path(release, platform, id)) if controllable_rollout?
  end

  def more_actions
    return [] if store_rollout.completed? || store_rollout.fully_released? || store_rollout.created?

    case store_rollout.status.to_sym
    when :started
      [action_button("Halt rollout", halt_release_platform_store_rollout_path(release, platform, id), scheme: :danger),
        action_button("Release to all", fully_release_release_platform_store_rollout_path(release, platform, id), scheme: :light),
        (action_button("Pause rollout", pause_release_platform_store_rollout_path(release, platform, id), scheme: :danger) if automatic_rollout?)].compact
    when :paused
      [action_button("Resume rollout", resume_release_platform_store_rollout_path(release, platform, id), scheme: :light)]
    when :halted
      [action_button("Resume rollout", resume_release_platform_store_rollout_path(release, platform, id), scheme: :light)]
    else
      raise "Invalid status: #{store_rollout.status}"
    end
  end

  def action_button(label, path, method: :patch, scheme: :default, size: :xxs)
    V2::ButtonComponent.new(label:, options: path, scheme:, size: size, html_options: {method:, data: {turbo_method: method, turbo_confirm: "Are you sure?"}})
  end

  def card_height
    return "60" if compact?
    "80"
  end
end
