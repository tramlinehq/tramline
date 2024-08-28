# frozen_string_literal: true

require "rails_helper"

describe Coordinators::StartProductionRelease do
  describe "call" do
    it "starts a submission" do
      release_platform_run = create(:release_platform_run)
      workflow_run = create(:workflow_run, :rc, release_platform_run:)
      expect { described_class.call(release_platform_run, workflow_run.build.id) }.to change(StoreSubmission, :count).by(1)
    end
  end
end
