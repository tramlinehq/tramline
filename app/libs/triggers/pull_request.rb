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
    if existing_pr.present?
      @pull_request = existing_pr
      pr_data = train.vcs_provider.get_pr(@pull_request.number)
      # FIXME: update the PR details, not just state
      return GitHub::Result.new { @pull_request.close! } if pr_data[:state] == "closed"
    else
      return GitHub::Result.new { allow_without_diff } unless create.ok?
      @pull_request = @new_pull_request.update_or_insert!(create.value!)
    end

    merge.then { GitHub::Result.new { @pull_request.close! } }
  end

  private

  attr_reader :release, :to_branch_ref, :from_branch_ref, :title, :description, :existing_pr

  memoize def create
    GitHub::Result.new do
      repo_integration.create_pr!(to_branch_ref, from_branch_ref, title, description)
    rescue Installations::Errors::PullRequestAlreadyExists
      repo_integration.find_pr(to_branch_ref, from_branch_ref)
    rescue Installations::Errors::PullRequestWithoutCommits
      raise CreateError, "Could not create a Pull Request"
    end
  end

  memoize def merge
    GitHub::Result.new do
      repo_integration.merge_pr!(@pull_request.number)
    rescue Installations::Errors::PullRequestNotMergeable
      release.event_stamp!(reason: :pull_request_not_mergeable, kind: :error, data: {url: @pull_request.url, number: @pull_request.number})
      raise MergeError, "Failed to merge the Pull Request"
    end
  end

  def allow_without_diff
    @allow_without_diff ? true : raise(CreateError, "Could not create a Pull Request without a diff")
  end

  def repo_integration
    train.vcs_provider
  end
end
