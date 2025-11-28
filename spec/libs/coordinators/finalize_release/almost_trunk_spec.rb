require "rails_helper"

describe Coordinators::FinalizeRelease::AlmostTrunk do
  describe ".call" do
    it_behaves_like "end of release tagging"
    it_behaves_like "end of release pull request creation for almost trunk"
  end
end
