# frozen_string_literal: true

require "rails_helper"

describe Coordinators::StopRelease do
  describe ".call" do
    it "updates the train version if partially finished" do
      train = create(:train, version_seeded_with: "9.59.3")
      release = create(:release, :partially_finished, train:)

      described_class.call(release)
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end

    it "does not update the train version if properly stopped" do
      train = create(:train, version_seeded_with: "9.59.3")
      release = create(:release, :post_release_started, train:)

      described_class.call(release)
      train.reload

      expect(train.version_current).to eq("9.59.3")
    end
  end
end
