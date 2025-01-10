class Triggers::PullRequest
  include Memery

  CreateError = Class.new(StandardError)
  MergeError = Class.new(StandardError)
  RetryableMergeError = Class.new(MergeError)

  def self.create_and_merge!(**args)
    new(**args).create_and_merge!
  end

  def initialize(release:, new_pull_request:, to_branch_ref:, from_branch_ref:, title:, description:, allow_without_diff: true, existing_pr: nil, patch_pr: false, patch_commit: nil)
    @release = release
    @to_branch_ref = to_branch_ref
    @from_branch_ref = from_branch_ref
    @title = title
    @description = description
    @new_pull_request = new_pull_request
    @allow_without_diff = allow_without_diff
    @existing_pr = existing_pr
    @patch_pr = patch_pr
    @patch_commit = patch_commit
  end

  delegate :train, to: :release

  def create_and_merge!
    pr_in_work = existing_pr if existing_pr&.persisted?

    if pr_in_work.present?
      pr_data = repo_integration.get_pr(pr_in_work.number)
      if repo_integration.pr_closed?(pr_data)
        return GitHub::Result.new { pr_in_work.close! } # FIXME: update the PR details, not just state
      end
    end

    if pr_in_work.blank?
      result = create!

      if result.ok?
        pr_in_work = @new_pull_request.update_or_insert!(result.value!)
      else
        # ignore the specific create error if PRs are allowed without diffs
        if @allow_without_diff && pr_without_commits_error?(result)
          return GitHub::Result.new { true }
        end

        # otherwise, just raise a standard create error
        return GitHub::Result.new { raise CreateError, result.error.message }
      end
    end

    # defensive check to ensure the PR is not closed in between (via a webhook perhaps)
    pr_in_work.reload
    return GitHub::Result.new { pr_in_work } if pr_in_work.closed?

    # try and merge, when:
    # - create PR is successful
    # - or PR already exists and is _not_ already closed
    merge_result = merge!(pr_in_work)
    if merge_result.ok?
      pr_in_work.close!
    elsif enable_auto_merge? # enable auto-merge if possible
      repo_integration.enable_auto_merge!(pr_in_work.number)
    else
      return merge_result
    end

    GitHub::Result.new { pr_in_work }
  end

  private

  attr_reader :release, :to_branch_ref, :from_branch_ref, :title, :description, :existing_pr

  def create!
    GitHub::Result.new do
      create_new_pr!
    rescue Installations::Error => ex
      raise ex unless ex.reason == :pull_request_already_exists
      repo_integration.find_pr(to_branch_ref, from_branch_ref)
    end
  end

  def merge!(pr)
    GitHub::Result.new do
      repo_integration.merge_pr!(pr.number)
    rescue Installations::Error => ex
      if ex.reason == :pull_request_not_mergeable
        release.event_stamp!(reason: :pull_request_not_mergeable, kind: :error, data: {url: pr.url, number: pr.number})
        raise MergeError, "Failed to merge the Pull Request"
      elsif ex.reason == :pull_request_failed_merge_check
        raise RetryableMergeError, "Failed to merge the Pull Request because of merge checks."
      else
        raise ex
      end
    end
  end

  def pr_without_commits_error?(result)
    result.error.is_a?(Installations::Error) && result.error.reason == :pull_request_without_commits
  end

  def create_new_pr!
    if @patch_pr && @patch_commit
      repo_integration.create_patch_pr!(to_branch_ref, from_branch_ref, @patch_commit&.commit_hash, title, description)
    else
      repo_integration.create_pr!(to_branch_ref, from_branch_ref, title, description)
    end
  end

  def enable_auto_merge?
    repo_integration.enable_auto_merge?
  end

  memoize def repo_integration
    train.vcs_provider
  end
end
