class Triggers::CherryPickPullRequest
  def self.call(release, forward_merge_queue)
    new(release, forward_merge_queue).call
  end

  def initialize(release, forward_merge_queue)
    @release = release
    @forward_merge_queue = forward_merge_queue
    @commit = forward_merge_queue.commit
    @pull_request = Triggers::PullRequest.new(
      release: release,
      new_pull_request_attrs: {
        phase: :mid_release,
        kind: :cherry_pick,
        release_id: release.id,
        state: :open,
        forward_merge_queue_id: forward_merge_queue.id
      },
      to_branch_ref: release.branch_name,
      from_branch_ref: patch_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: forward_merge_queue.pull_request,
      patch_pr: true,
      patch_commit: commit
    )
  end

  def call
    @pull_request.create_and_merge!
  end

  private

  delegate :train, to: :release
  delegate :working_branch, to: :train
  attr_reader :release, :forward_merge_queue, :commit

  def pr_title
    "[CHERRY-PICK] [#{release.release_version}] #{commit.message.to_s.split("\n").first}".gsub(/\s*\(#\d+\)/, "").squish
  end

  def pr_description
    <<~TEXT
      - Cherry-pick #{commit.commit_hash} from #{working_branch} into #{release.branch_name}
      - Authored by: @#{commit.author_login || commit.author_name}

      #{commit.message}
    TEXT
  end

  def patch_branch
    ["cherry-pick", release.branch_name.parameterize, commit.short_sha].join("-")
  end
end
