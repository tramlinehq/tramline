require "rails_helper"

describe Coordinators::FinalizeRelease::ParallelBranches do
  describe ".call" do
    it_behaves_like "end of release tagging"
  end
end
