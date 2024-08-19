class V2::LiveRelease::ProdRelease::RolloutComponent < V2::BaseComponent
  STATUS = {
    created: {text: "Ready", status: :routine},
    started: {text: "Active", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    completed: {text: "Completed", status: :success},
    halted: {text: "Halted", status: :inert},
    fully_released: {text: "Released to all users", status: :success},
    paused: {text: "Paused phased release", status: :ongoing}
  }

  # TODO: [V2] Add new monitoring component here
  def initialize(store_rollout, title: "Rollout Status")
    @store_rollout = store_rollout
    @title = title
  end

  attr_reader :store_rollout
  delegate :release_platform_run,
    :build,
    :provider,
    :last_rollout_percentage,
    :stage,
    :controllable_rollout?,
    :automatic_rollout?, :id, to: :store_rollout
  delegate :release, to: :release_platform_run

  def upcoming? = store_rollout.created?

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
    return if store_rollout.completed? || store_rollout.fully_released? || store_rollout.halted?

    if store_rollout.created?
      return V2::ButtonComponent.new(
        label: "Start rollout",
        scheme: :light,
        options: start_store_rollout_path(id),
        size: :xxs,
        html_options: html_opts(:patch, "Are you sure?")
      )
    end

    if controllable_rollout?
      V2::ButtonComponent.new(
        label: "Increase rollout",
        scheme: :default,
        options: increase_store_rollout_path(id),
        size: :xxs,
        html_options: html_opts(:patch, "Are you sure?")
      )
    end
  end

  def more_actions
    actions_by_status = {
      started: [
        {
          text: "Halt rollout",
          path: halt_store_rollout_path(id),
          scheme: :danger
        },
        {
          text: "Release to all",
          path: fully_release_store_rollout_path(id),
          scheme: :light
        },
        {
          text: "Pause rollout",
          path: pause_store_rollout_path(id),
          scheme: :danger,
          disabled: !automatic_rollout?
        }
      ],
      paused: [
        {
          text: "Resume rollout",
          path: resume_store_rollout_path(id),
          scheme: :light
        }
      ],
      halted: [
        {
          text: "Resume rollout",
          path: resume_store_rollout_path(id),
          scheme: :light
        }
      ]
    }

    actions_by_status[store_rollout.status.to_sym]&.map do |action|
      V2::ButtonComponent.new(
        label: action[:text],
        scheme: action[:scheme],
        options: action[:path],
        disabled: action[:disabled],
        size: :xxs,
        html_options: html_opts(:patch, "Are you sure?")
      )
    end&.compact || []
  end

  def card_height
    if upcoming?
      "60"
    else
      "80"
    end
  end

  def border_style
    :dashed if upcoming?
  end

  def store_dashboard_link
    "https://play.google.com/store/apps/details?id=com.example.app"
  end
end
