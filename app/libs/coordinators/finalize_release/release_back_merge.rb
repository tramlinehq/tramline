class Coordinators::FinalizeRelease::ReleaseBackMerge
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
  end

  def call
    create_tag.then { create_and_merge_prs }
  end

  private

  attr_reader :train, :release
  delegate :release_backmerge_branch, :working_branch, to: :train
  delegate :branch_name, to: :release
  delegate :logger, to: Rails

  def create_and_merge_prs
    Triggers::PullRequest.create_and_merge!(
      release: release,
      new_pull_request: release.pull_requests.post_release.open.build,
      to_branch_ref: release_backmerge_branch,
      from_branch_ref: branch_name,
      title: release_pr_title,
      description: pr_description(branch_name, release_backmerge_branch)
    ).then do
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: release_backmerge_branch,
        title: backmerge_pr_title,
        description: pr_description(release_backmerge_branch, working_branch)
      )
    end.then do |value|
      stamp_pr_success
      GitHub::Result.new { value }
    end
  end

  def stamp_pr_success
    release.reload.pull_requests.post_release.each do |pr|
      release.event_stamp!(reason: :post_release_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number})
    end
  end

  def create_tag
    GitHub::Result.new { release.create_release! }
  end

  def release_pr_title
    "[#{release.release_version}] Merge to finalize release"
  end

  def backmerge_pr_title
    "[#{release.release_version}] Backmerge to working branch"
  end

  def pr_description(from, to)
    <<~TEXT
      The release train #{train.name} with version #{release.release_version} has finished.
      The #{from} branch has to be merged into #{to} branch.
    TEXT
  end
end
