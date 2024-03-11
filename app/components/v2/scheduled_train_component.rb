class V2::ScheduledTrainComponent < V2::BaseComponent
  include TrainsHelper

  def initialize(train)
    @train = train
    @ongoing_release = train.ongoing_release

    previous_time =
      if @ongoing_release.present?
        if @ongoing_release.is_automatic?
          @ongoing_release.scheduled_release.sheduled_at
        else
          @ongoing_release.scheduled_at
        end
      else
        Time.current
      end

    @past_releases = train.scheduled_releases.where("scheduled_at < ?", previous_time).order(scheduled_at: :asc).last(2)
    @future_release = train.scheduled_releases.pending.order(scheduled_at: :asc).first
  end

  attr_reader :ongoing_release, :past_releases, :future_release, :train

  def scheduled_release_status(scheduled_release)
    return unless scheduled_release
    release = scheduled_release.release
    return release_status(release) if release.present?
    return {text: "Pending", status: :routine} if scheduled_release.pending?
    return {text: "Completed", status: :success} if scheduled_release.is_success
    {text: "Skipped", status: :neutral}
  end

  def release_status(release)
    status = ReleasesHelper::SHOW_RELEASE_STATUS.fetch(release.status.to_sym)
    {text: status.first, status: status.last}
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
    return "No release is running" if ongoing_release.blank?
    "Kickoff at #{time_format(ongoing_release.scheduled_at, only_time: true)}"
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

  def next_to_next_run_at
    return unless future_release
    future_release.scheduled_at + train.repeat_duration
  end
end
