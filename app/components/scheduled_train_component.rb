class ScheduledTrainComponent < BaseComponent
  def initialize(train)
    @train = train

    previous_time =
      if current_release.present?
        if current_release.is_automatic?
          current_release.scheduled_release.scheduled_at
        else
          current_release.scheduled_at
        end
      else
        Time.current
      end

    @past_releases = train.scheduled_releases.past(2, before: previous_time)
    @future_release = train.scheduled_releases.future.first
  end

  attr_reader :past_releases, :future_release, :train

  def scheduled_release_status(scheduled_release)
    return unless scheduled_release
    release = scheduled_release.release
    return release_status(release) if release.present?
    return {text: "Pending", status: :routine} if scheduled_release.pending?
    return {text: "Manually skipped", status: :neutral} if scheduled_release.manually_skipped?
    return {text: "Completed", status: :success} if scheduled_release.is_success
    {text: "Skipped", status: :neutral}
  end

  def future_release_status
    {text: "Pending", status: :routine}
  end

  def skip_or_resume_button(scheduled_release)
    return if scheduled_release.nil?
    return unless scheduled_release.skip_or_resume?

    if scheduled_release.manually_skipped?
      label = "Resume"
      icon = "play.svg"
      path = resume_app_train_scheduled_release_path(train.app, train, scheduled_release)
      confirmation_message = "This will resume the upcoming scheduled release. Are you sure?"
    else
      label = "Skip this release"
      icon = "circle_arrow_right.svg"
      path = skip_app_train_scheduled_release_path(train.app, train, scheduled_release)
      confirmation_message = "This will skip the upcoming scheduled release. Are you sure?"
    end

    button = ButtonComponent.new(
      scheme: :light,
      label: label,
      options: path,
      type: :button,
      html_options: {
        method: :patch,
        data: {turbo_method: :patch, turbo_confirm: confirmation_message}
      }
    )

    button.with_icon(icon)
    button
  end

  def release_status(release)
    ReleasePresenter.new(release, self).release_status
  end

  def inactive_status
    {text: "Inactive", status: :failure} if train.inactive?
  end

  def time_text(scheduled_release)
    return unless scheduled_release
    return "Scheduled for #{time_format(scheduled_release.scheduled_at, only_time: true)}" if scheduled_release.scheduled_at.past? || scheduled_release.scheduled_at.future?
    "Running"
  end

  def ongoing_text
    return "No release is running" if current_release.blank?
    "Kickoff at #{time_format(current_release.scheduled_at, only_time: true)}"
  end

  def past_text(past_release)
    return unless past_release
    return "Originally scheduled for #{time_format(past_release.scheduled_at, only_time: true)}" unless past_release.is_success?
    "Started at #{time_format(past_release.scheduled_at, only_time: true)}"
  end

  def past_title(past_release)
    return unless past_release
    past_release.release&.release_version
  end

  def next_run_at
    return unless future_release
    future_release.scheduled_at
  end

  def next_to_next_run_at
    return unless future_release
    future_release.scheduled_at + train.repeat_duration
  end

  def next_version
    (current_release || train).next_version(relative_time: next_run_at)
  end

  def next_next_version
    (current_release || train).next_to_next_version(relative_time: next_to_next_run_at)
  end

  def current_release
    @current_release ||= train.active_runs.max_by(&:scheduled_at)
  end
end
