class V2::LiveRelease::ProdRelease::RolloutComponent < V2::BaseComponent
  include Memery
  CASCADING_ROLLOUTS_NOTICE = "Since cascading rollouts are enabled, this release will not fully rollout to 100% until rollout for the next release starts."

  def initialize(store_rollout, title: "Rollout Status")
    @store_rollout = store_rollout
    @title = title
  end

  STATUS = {
    created: {text: "Ready", status: :routine},
    started: {text: "Active", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    completed: {text: "Completed", status: :success},
    halted: {text: "Halted", status: :inert},
    fully_released: {text: "Released to all users", status: :success},
    paused: {text: "Paused phased release", status: :ongoing}
  }

  attr_reader :store_rollout
  delegate :release_platform_run,
    :created?,
    :build,
    :status,
    :provider,
    :last_rollout_percentage,
    :stage,
    :controllable_rollout?,
    :store_submission,
    :latest_events,
    :external_link,
    :automatic_rollout?, :id, to: :store_rollout
  delegate :release, to: :release_platform_run

  def decorated_status
    status_picker(STATUS, status)
  end

  def store_icon
    "integrations/logo_#{provider}.png"
  end

  def monitoring_size
    release_platform_run.app.cross_platform? ? :compact : :max
  end

  def show_blocked_message?
    release_platform_run.play_store_blocked? && !store_submission.failed_with_action_required?
  end

  def cascading_rollout_notice?
    store_submission.finish_rollout_in_next_release? && !store_rollout.created? && !store_rollout.fully_released?
  end

  def events
    latest_events.map do |event|
      {
        timestamp: time_format(event.event_timestamp, with_year: false),
        title: I18n.t("passport.store_rollout.reasons.#{event.reason}"),
        description: event.message,
        type: event.kind.to_sym
      }
    end
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
        html_options: html_opts(:patch, "Are you sure you want to start the rollout?")
      )
    end

    if controllable_rollout?
      V2::ButtonComponent.new(
        label: "Increase rollout",
        scheme: :default,
        options: increase_store_rollout_path(id),
        size: :xxs,
        html_options: html_opts(:patch, "Are you sure you want to increase the rollout?")
      )
    end
  end

  def more_actions
    actions_by_status = {
      started: [
        {
          text: "Halt rollout",
          path: halt_store_rollout_path(id),
          scheme: :danger,
          confirm: "Are you sure you want to halt the rollout?"
        },
        {
          text: "Release to all",
          path: fully_release_store_rollout_path(id),
          scheme: :light,
          confirm: "Are you sure you want to rollout to all users?"
        },
        {
          text: "Pause rollout",
          path: pause_store_rollout_path(id),
          scheme: :danger,
          disabled: !automatic_rollout?,
          confirm: "Are you sure you want to pause the rollout?"
        }
      ],
      paused: [
        {
          text: "Resume rollout",
          path: resume_store_rollout_path(id),
          scheme: :light,
          confirm: "Are you sure you want to resume the rollout?"
        }
      ],
      halted: [
        {
          text: "Resume rollout",
          path: resume_store_rollout_path(id),
          scheme: :light,
          confirm: "Are you sure you want to resume the rollout?"
        }
      ]
    }

    actions_by_status[store_rollout.status.to_sym]&.filter_map do |action|
      V2::ButtonComponent.new(
        label: action[:text],
        scheme: action[:scheme],
        options: action[:path],
        disabled: action[:disabled],
        size: :xxs,
        html_options: html_opts(:patch, action[:confirm])
      )
    end || []
  end

  def card_height
    if created?
      "60"
    else
      "88"
    end
  end

  def border_style
    :dashed if created?
  end
end
