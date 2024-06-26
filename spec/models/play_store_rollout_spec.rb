# frozen_string_literal: true

require "rails_helper"

describe PlayStoreRollout do
  describe "#start!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:rollout) { create(:store_rollout, :play_store, release_platform_run:, store_submission:) }

    it "informs the production release" do
      expect(production_release).to receive(:rollout_started!)
      rollout.start!
    end
  end
end
