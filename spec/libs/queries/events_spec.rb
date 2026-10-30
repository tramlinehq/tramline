require "rails_helper"

describe Queries::Events do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }

  describe ".all" do
    context "when no release platform run matches the platform filter" do
      let(:params) do
        Queries::Helpers::Parameters.new.tap { |p| p.add_filter(:ios_platform, "ios") }
      end

      it "does not raise" do
        expect { described_class.all(release:, params:).to_a }.not_to raise_error
      end

      it "still includes events stamped on the release itself" do
        passport = Passport.create!(stampable: release, reason: "created", kind: :notice, message: "created", event_timestamp: Time.current)

        expect(described_class.all(release:, params:)).to include(passport)
      end
    end
  end
end
