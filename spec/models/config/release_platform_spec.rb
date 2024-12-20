require "rails_helper"

describe Config::ReleasePlatform do
  let(:app) { create(:app, :ios) }
  let(:base_config) {
    {
      workflows: {
        internal: nil,
        release_candidate: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil
        }
      },
      internal_release: nil,
      beta_release: nil,
      production_release: {
        auto_promote: false,
        submissions: [
          {number: 1,
           integrable_id: app.id,
           integrable_type: "App",
           submission_type: "AppStoreSubmission",
           submission_config: AppStoreIntegration::PROD_CHANNEL,
           rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
           auto_promote: false}
        ]
      }
    }
  }

  describe "validations" do
    it "validates presence of release_candidate" do
      release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
      release_platform.release_candidate_workflow = nil
      expect(release_platform).not_to be_valid
      expect(release_platform.errors.messages[:release_candidate_workflow]).to include("the release candidate workflow must be configured")
    end

    it "validates presence of beta_release" do
      release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
      release_platform.beta_release = nil
      expect(release_platform).not_to be_valid
      expect(release_platform.errors.messages[:beta_release]).to include("the beta release must be configured")
    end
  end

  describe "#has_restricted_public_channels?" do
    it "returns false for an ios config" do
      config = described_class.from_json(base_config.merge(release_platform: create(:release_platform, platform: "ios")))
      expect(config.has_restricted_public_channels?).to be(false)
    end

    context "when android" do
      let(:app) { create(:app, :android) }
      let(:release_platform) { create(:release_platform, app:, platform: "android") }
      let(:base_config) {
        {
          workflows: {
            internal: nil,
            release_candidate: {
              name: Faker::FunnyName.name,
              id: Faker::Number.number(digits: 8),
              artifact_name_pattern: nil
            }
          },
          internal_release: nil,
          beta_release: nil,
          production_release: {
            auto_promote: false,
            submissions: [
              {number: 1,
               integrable_id: app.id,
               integrable_type: "App",
               submission_type: "PlayStoreSubmission",
               submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
               rollout_config: {enabled: true, stages: [1, 5, 10, 50, 100]},
               auto_promote: false}
            ]
          }
        }
      }

      it "returns true when production release is enabled" do
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns true when there are public tracks in internal release" do
        base_config[:internal_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "alpha", name: "Closed testing - Alpha"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns true when there are public tracks in beta release" do
        base_config[:beta_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "beta", name: "Open testing"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns false when there no public tracks in any release" do
        base_config[:internal_release] = {
          submissions: [
            {number: 1,
             submission_type: "GoogleFirebaseSubmission",
             submission_config: {id: "testing-group-1", name: "Testing Group 1"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:beta_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "internal", name: "Internal testing"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(false)
      end
    end
  end
end
