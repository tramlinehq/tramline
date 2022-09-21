module Installations
  module Errors
    class TagReferenceAlreadyExists < StandardError; end

    class PullRequestNotMergeable < StandardError; end

    class PullRequestWithoutCommits < StandardError; end

    class PullRequestAlreadyExists < StandardError; end
  end
end
