class Coordinators::FinalizeRelease::AlmostTrunk
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
  end

  # FIXME: Merge back to upcoming release branch also if it exists
  def call
    if release.continuous_backmerge?
      create_tag
    else
      create_tag.then { create_and_merge_pr }
    end
  end

  private

  attr_reader :train, :release
  delegate :logger, to: Rails
  delegate :working_branch, to: :train
  delegate :release_branch, to: :release

  def create_and_merge_pr
    Triggers::PullRequest.create_and_merge!(
      release: release,
      new_pull_request_attrs: {phase: :post_release, kind: :back_merge, release_id: release.id, state: :open},
      to_branch_ref: working_branch,
      from_branch_ref: release_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: release.pull_requests.post_release.back_merge_type.first
    )
  end

  def create_tag
    GitHub::Result.new do
      if train.tag_end_of_release?
        release.create_vcs_release!(release.last_commit.commit_hash, release.release_diff)
      end
    end
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
