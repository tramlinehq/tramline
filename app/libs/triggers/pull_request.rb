module Automatons
  class PullRequest
    Result = Struct.new(:ok?, :error, :value, keyword_init: true)
    delegate :transaction, to: ApplicationRecord

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
      return Result.new(ok?: allow_without_diff) unless create.ok?
      upserted_pull_request = @new_pull_request.update_or_insert!(create.value)

      ::Releases::PullRequest.transaction do
        upserted_pull_request.close!

        if merge.ok?
          Result.new(ok?: true)
        else
          return Result.new(ok?: false, error: "Failed to create / merge the Pull Request")
        end
      end
    end

    private

    attr_reader :release, :to_branch_ref, :from_branch_ref, :title, :description, :allow_without_diff

    def create
      @create_result ||=
        begin
          Result.new(ok?: true, value: repo_integration.create_pr!(repo_name, to_branch_ref, from_branch_ref, title, description))
        rescue Installations::Errors::PullRequestAlreadyExists
          Result.new(ok?: true, value: repo_integration.find_pr(repo_name, to_branch_ref, from_branch_ref))
        rescue Installations::Errors::PullRequestWithoutCommits
          release.event_stamp!(reason: :pull_request_not_required, kind: :notice, data: {to: to_branch_ref, from: from_branch_ref})
          Result.new(ok?: false, error: "Could not create a Pull Request")
        end
    end

    def merge
      repo_integration.merge_pr!(repo_name, create.value[:number])
      Result.new(ok?: true)
    rescue Installations::Errors::PullRequestNotMergeable
      release.event_stamp!(reason: :pull_request_not_mergeable, kind: :notice, data: {})
      Result.new(ok?: false, error: "Failed to merge the Pull Request")
    end

    def repo_name
      train.app.config.code_repository_name
    end

    def repo_integration
      train.vcs_provider.installation
    end
  end
end
