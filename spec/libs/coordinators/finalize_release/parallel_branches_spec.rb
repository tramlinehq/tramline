require "rails_helper"

describe Coordinators::FinalizeRelease::ParallelBranches do
  describe ".call" do
    it_behaves_like "end of release tagging"
    it_behaves_like "end of release pull request creation for parallel branches"
  end
end
