class Triggers::PullRequest
  include Memery

  CreateError = Class.new(StandardError)
  MergeError = Class.new(StandardError)

  def self.create_and_merge!(**args)
    new(**args).create_and_merge!
  end

  def initialize(release:, new_pull_request:, to_branch_ref:, from_branch_ref:, title:, description:, allow_without_diff: true, existing_pr: nil)
    @release = release
    @to_branch_ref = to_branch_ref
    @from_branch_ref = from_branch_ref
    @title = title
    @description = description
    @new_pull_request = new_pull_request
    @allow_without_diff = allow_without_diff
    @existing_pr = existing_pr
  end

  delegate :train, to: :release

  def create_and_merge!
    pr_in_work = existing_pr

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
    merge!(pr_in_work).then { GitHub::Result.new { pr_in_work.close! } }
  end

  private

  attr_reader :release, :to_branch_ref, :from_branch_ref, :title, :description, :existing_pr

  def create!
    GitHub::Result.new do
      repo_integration.create_pr!(to_branch_ref, from_branch_ref, title, description)
    rescue Installations::Error => ex
      return repo_integration.find_pr(to_branch_ref, from_branch_ref) if ex.reason == :pull_request_already_exists
      raise ex
    end
  end

  def merge!(pr)
    GitHub::Result.new do
      repo_integration.merge_pr!(pr.number)
    rescue Installations::Error => ex
      if ex.reason == :pull_request_not_mergeable
        release.event_stamp!(reason: :pull_request_not_mergeable, kind: :error, data: {url: pr.url, number: pr.number})
        raise MergeError, "Failed to merge the Pull Request"
      else
        raise ex
      end
    end
  end

  memoize def repo_integration
    train.vcs_provider
  end

  def pr_without_commits_error?(result)
    result.error.is_a?(Installations::Error) && result.error.reason == :pull_request_without_commits
  end
end
