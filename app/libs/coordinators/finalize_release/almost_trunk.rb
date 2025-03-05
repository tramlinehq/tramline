class Coordinators::FinalizeRelease::AlmostTrunk
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
  end

  def call
    if release.continuous_backmerge?
      create_tag
    else
      create_tag.then do
        create_and_merge_pr(working_branch).then do
          if train.backmerge_to_upcoming_release && train.upcoming_release
            create_and_merge_pr(train.upcoming_release.branch_name)
          end
        end
      end
    end
  end

  private

  attr_reader :train, :release
  delegate :logger, to: Rails
  delegate :working_branch, to: :train
  delegate :release_branch, to: :release

  def create_and_merge_pr(to_branch_ref)
    Triggers::PullRequest.create_and_merge!(
      release: release,
      new_pull_request: release.pull_requests.post_release.open.build,
      to_branch_ref: to_branch_ref,
      from_branch_ref: release_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: release.pull_requests.post_release.find_by(base_ref: to_branch_ref)
    ).then do |value|
      logger.info "AT: Create and merge PR result - #{value}"
      stamp_pr_success(to_branch_ref)
      GitHub::Result.new { value }
    end
  end

  def stamp_pr_success(to_branch_ref)
    pr = release.reload.pull_requests.post_release.find_by(base_ref: to_branch_ref)
    release.event_stamp!(reason: :post_release_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number}) if pr
  end

  def create_tag
    GitHub::Result.new { release.create_vcs_release! }
  end

  def pr_title
    "[#{release.release_version}] Post-release merge"
  end

  def pr_description
    <<~TEXT
      The release train #{train.name} with version #{release.release_version} has finished.
      The #{release_branch} branch has to be merged into #{working_branch} branch.
    TEXT
  end
end
