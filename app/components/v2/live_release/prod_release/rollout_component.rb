class V2::LiveRelease::ProdRelease::RolloutComponent < V2::BaseComponent
  def initialize(store_rollout, title: "Rollout Status")
    @store_rollout = ::StoreRolloutPresenter.new(store_rollout, self)
    @title = title
  end

  attr_reader :store_rollout
  delegate :release_platform_run,
    :upcoming?,
    :decorated_status,
    :store_icon,
    :build,
    :provider,
    :last_rollout_percentage,
    :stage,
    :controllable_rollout?,
    :store_submission,
    :latest_events,
    :external_link,
    :automatic_rollout?, :id, to: :store_rollout
  delegate :release, to: :release_platform_run

  def monitoring_size
    release_platform_run.app.cross_platform? ? :compact : :default
  end

  def show_blocked_message?
    release_platform_run.play_store_blocked? && !store_submission.failed_with_action_required?
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
      "88"
    end
  end

  def border_style
    :dashed if upcoming?
  end
end
