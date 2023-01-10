class Triggers::PullRequest
  include Memery

  class CreateError < StandardError; end

  class MergeError < StandardError; end

  delegate :transaction, to: ::Releases::PullRequest

  def self.create_and_merge!(**args)
    new(**args).create_and_merge!
  end

  delegate :train, to: :release

  def initialize(release:, new_pull_request:, to_branch_ref:, from_branch_ref:, title:, description:, allow_without_diff: true)
    @release = release
    @to_branch_ref = to_branch_ref
    @from_branch_ref = from_branch_ref
    @title = title
    @description = description
    @new_pull_request = new_pull_request
    @allow_without_diff = allow_without_diff
  end

  def create_and_merge!
    return GitHub::Result.new { allow_without_diff } unless create.ok?
    upserted_pull_request = @new_pull_request.update_or_insert!(create.value!)

    GitHub::Result.new do
      transaction do
        upserted_pull_request.close!
        merge.value!
      end
    end
  end

  private

  attr_reader :release, :to_branch_ref, :from_branch_ref, :title, :description

  memoize def create
    GitHub::Result.new do
      repo_integration.create_pr!(repo_name, to_branch_ref, from_branch_ref, title, description)
    rescue Installations::Errors::PullRequestAlreadyExists
      repo_integration.find_pr(repo_name, to_branch_ref, from_branch_ref)
    rescue Installations::Errors::PullRequestWithoutCommits
      release.event_stamp!(reason: :pull_request_not_required, kind: :notice, data: {to: to_branch_ref, from: from_branch_ref})
      raise CreateError, "Could not create a Pull Request"
    end
  end

  memoize def merge
    GitHub::Result.new do
      repo_integration.merge_pr!(repo_name, create.value![:number])
    rescue Installations::Errors::PullRequestNotMergeable
      release.event_stamp!(reason: :pull_request_not_mergeable, kind: :notice, data: {})
      raise MergeError, "Failed to merge the Pull Request"
    end
  end

  def allow_without_diff
    @allow_without_diff ? true : raise(CreateError, "Could not create a Pull Request without a diff")
  end

  def repo_name
    train.app.config.code_repository_name
  end

  def repo_integration
    train.vcs_provider.installation
  end
end
