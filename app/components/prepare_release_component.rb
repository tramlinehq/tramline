class PrepareReleaseComponent < BaseComponent
  include Memery

  SIZE = {
    default: {
      modal: :default,
      modal_button: :xxs,
      modal_icon: :md,
      branch_icon: :md
    },
    xxs: {
      modal: :xxs,
      modal_button: :xxs,
      modal_icon: :sm,
      branch_icon: :xl
    }
  }.freeze

  REVEAL_HIDE_ACTION = "reveal#hide"
  REVEAL_SHOW_ACTION = "reveal#show"

  def initialize(train:, label: "Prepare new release", size: :default)
    @train = train
    @label = label
    @size = size
  end

  attr_reader :train, :label, :size
  delegate :app, to: :train

  def release_startable?
    app.ready? && release_options.present?
  end

  def release_form_partial
    "release_list/#{train.versioning_strategy}_form"
  end

  def release_options
    return [] if train.inactive?
    upcoming_release_startable = train.upcoming_release_startable?
    return [] if train.ongoing_release && !upcoming_release_startable

    start_minor_text = start_release_text
    start_major_text = start_release_text(major: true)
    start_minor_text = start_upcoming_release_text if upcoming_release_startable
    start_major_text = start_upcoming_release_text(major: true) if upcoming_release_startable

    return frozen_version_options(start_release_text) if train.freeze_version

    case train.versioning_strategy
    when "semver" then semver_options(start_major_text, start_minor_text)
    when "calver" then calver_options(start_major_text)
    else raise
    end
  end

  def frozen_version_options(subtitle)
    [
      {
        title: "Fixed version",
        subtitle:,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def semver_options(major_subtitle, minor_subtitle)
    [
      {
        title: "Minor",
        subtitle: minor_subtitle,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      {
        title: "Major",
        subtitle: major_subtitle,
        icon: "forward_step_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: false, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def custom_version_option
    {
      title: "Custom",
      subtitle: "Specify a release version",
      icon: "user_cog_fill.svg",
      opt_name: "has_major_bump",
      opt_value: nil,
      options: {checked: false, data: {action: REVEAL_SHOW_ACTION}}
    }
  end

  def calver_options(subtitle)
    [
      {
        title: "Calendar version",
        subtitle:,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def branch_help_html
    substitution_tokens = {trainName: train.display_name, releaseStartDate: Time.current, releaseVersion: "<newVersion>"}
    new_branch = train.release_branch_name_fmt(hotfix: false, substitution_tokens:)
    working_branch = train.working_branch
    content_tag(:span) do
      safe_join(
        [
          "Release branch ",
          content_tag(:code, new_branch),
          " will be cut from ",
          content_tag(:code, working_branch),
          "."
        ]
      )
    end
  end

  def modal_size
    SIZE.fetch(size, SIZE[:default])[:modal]
  end

  def modal_button_size
    SIZE.fetch(size, SIZE[:default])[:modal_button]
  end

  def modal_icon_size
    SIZE.fetch(size, SIZE[:default])[:modal_icon]
  end

  def branch_icon_size
    SIZE.fetch(size, SIZE[:default])[:branch_icon]
  end

  private

  def start_release_text(major: false)
    text =
      if train.freeze_version?
        "Fixed version "
      elsif train.automatic?
        "Manually release version "
      elsif train.calver?
        "Next CalVer will be "
      else
        "Release version "
      end

    version = train.freeze_version? ? train.version_current : train.next_version(major_only: major)
    text + version
  end

  def start_upcoming_release_text(major: false)
    text = "Prepare next "
    text += "release "
    text + train.ongoing_release.next_version(major_only: major)
  end
end
