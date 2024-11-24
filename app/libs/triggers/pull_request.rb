class Triggers::PullRequest
  include Memery

  class CreateError < StandardError; end

  class MergeError < StandardError; end

  delegate :transaction, to: ::PullRequest

  def self.create_and_merge!(**args)
    new(**args).create_and_merge!
  end

  delegate :train, to: :release

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

  def create_and_merge!
    pr_in_work = existing_pr

    if existing_pr.present?
      pr_data = train.vcs_provider.get_pr(existing_pr.number)
      if repo_integration.pr_closed?(pr_data)
        # FIXME: update the PR details, not just state
        return GitHub::Result.new { existing_pr.close! }
      end
    end

    if existing_pr.blank?
      create_res = create!
      if create_res.ok?
        pr_in_work = @new_pull_request.update_or_insert!(create_res.value!)
      else
        if create_res.error.is_a?(Installations::Error) && create_res.error.reason == :pull_request_without_commits && @allow_without_diff
          return GitHub::Result.new { true }
        end

        return CreateError res.error.message
      end
    end

    return GitHub::Result.new { pr_in_work } if pr_in_work.closed?
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
        release.event_stamp!(reason: :pull_request_not_mergeable, kind: :error, data: { url: pr.url, number: pr.number })
        raise MergeError, "Failed to merge the Pull Request"
      else
        raise ex
      end
    end
  end

  def repo_integration
    train.vcs_provider
  end
end
