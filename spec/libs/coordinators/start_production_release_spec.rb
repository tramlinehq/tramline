# frozen_string_literal: true

require "rails_helper"

describe Coordinators::StartProductionRelease do
  describe "call" do
    it "starts a submission" do
      release_platform_run = create(:release_platform_run)
      build = create(:build)
      create(:production_release, release_platform_run:, build:)
      expect { described_class.call(build) }.to change(StoreSubmission, :count).by(1)
    end
  end
end
