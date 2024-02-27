class Queries::ReleaseSummary
  include Memery
  include Loggable

  def self.warm(release_id)
    new(release_id).warm
  end

  def self.all(release_id)
    new(release_id).all
  end

  def initialize(release_id)
    @release_id = release_id
  end

  def warm
    cache.write(cache_key, data)
  rescue => e
    elog(e)
  end

  def all
    cache.fetch(cache_key)
  end

  class Queries::ReleaseSummary::Overall
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :tag, :string
    attribute :tag_url, :string
    attribute :version, :string
    attribute :kickoff_at, :datetime
    attribute :finished_at, :datetime
    attribute :backmerge_pr_count, :integer
    attribute :backmerge_failure_count, :integer
    attribute :commits_count, :integer
    attribute :duration, :integer
    attribute :is_hotfix, :boolean
    attribute :hotfixed_from, :string
    attribute :hotfixes, default: {}

    def self.from_release(release)
      attributes = {
        tag: release.tag_name,
        tag_url: release.tag_url,
        version: release.release_version,
        kickoff_at: release.scheduled_at,
        finished_at: release.completed_at,
        backmerge_pr_count: release.backmerge_prs.size,
        backmerge_failure_count: release.backmerge_failure_count,
        commits_count: release.all_commits.size,
        duration: release.duration&.seconds,
        is_hotfix: release.hotfix?,
        hotfixes: release.hotfixes.map { |r| [r.release_version, r.live_release_link] }.to_h
      }

      if release.hotfix?
        attributes[:hotfixed_from] = release.hotfixed_from.release_version
      end

      new(attributes)
    end

    def inspect
      format(
        "#<Queries::ReleaseSummary::Overall %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  class Queries::ReleaseSummary::StepsSummary
    def self.from_release(release)
      attributes = release.release_platform_runs.map do |pr|
        release_phase_start = pr.step_runs_for(pr.release_platform.release_step)&.first&.scheduled_at
        pr.steps.map do |step|
          step_runs = pr.step_runs_for(step).sequential
          started_at = step_runs.first&.scheduled_at
          ended_at = step.review? ? release_phase_start : step_runs.last&.updated_at
          {
            name: step.name,
            platform: pr.display_attr(:platform),
            platform_raw: pr.platform,
            started_at: started_at,
            phase: step.kind,
            ended_at: ended_at,
            duration: (ActiveSupport::Duration.seconds(ended_at - started_at) if started_at && ended_at),
            builds_created_count: step_runs.not_failed.size
          }
        end
      end

      new(attributes.flatten.map { StepSummary.new(_1) })
    end

    def initialize(steps_summary)
      @steps_summary = steps_summary
    end

    def all = @steps_summary

    class StepSummary
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :started_at, :datetime
      attribute :ended_at, :datetime
      attribute :duration, :integer
      attribute :platform, :string
      attribute :platform_raw, :string
      attribute :phase, :string
      attribute :builds_created_count, :integer
      attribute :name, :string
    end
  end

  class Queries::ReleaseSummary::StoreVersions
    def self.from_release(release)
      attributes = release.deployment_runs.order(created_at: :desc).reached_production.map do |dr|
        {
          version: dr.step_run.build_version,
          build_number: dr.step_run.build_number,
          built_at: dr.scheduled_at,
          submitted_at: dr.submitted_at,
          release_started_at: dr.release_started_at,
          staged_rollouts: dr.staged_rollout_events,
          platform: dr.release_platform_run.display_attr(:platform)
        }
      end

      new(attributes.map { StoreVersion.new(_1) })
    end

    def initialize(store_versions)
      @store_versions = store_versions
    end

    def all = @store_versions

    class StoreVersion
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :version, :string
      attribute :build_number, :string
      attribute :built_at, :datetime
      attribute :submitted_at, :datetime
      attribute :release_started_at, :datetime
      attribute :staged_rollouts, array: true, default: []
      attribute :platform, :string

      def inspect
        format(
          "#<Queries::ReleaseSummary::StoreVersions::StoreVersion %{attributes} >",
          attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
        )
      end
    end
  end

  private

  attr_reader :release_id
  delegate :cache, to: Rails

  memoize def release
    Release
      .where(id: release_id)
      .includes(:all_commits,
        :pull_requests,
        train: [:release_platforms],
        release_platform_runs: {step_runs: {deployment_runs: [{deployment: [:integration]}, :staged_rollout]}})
      .sole
  end

  def data
    {
      overall: Overall.from_release(release),
      steps_summary: StepsSummary.from_release(release),
      store_versions: StoreVersions.from_release(release),
      pull_requests: release.pull_requests.automatic,
      team_stability_commits: release.all_commits.count_by_team(release.organization),
      team_release_commits: release.release_changelog&.commits_by_team
    }
  end

  def thaw
    cache.delete(cache_key)
  end

  def cache_key
    "release/#{release_id}/summary"
  end
end
