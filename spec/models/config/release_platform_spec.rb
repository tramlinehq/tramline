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

    it "validates production release submission to not have AppVariant" do
      release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
      release_platform.production_release.submissions.first.update(integrable_type: "AppVariant")
      expect(release_platform).not_to be_valid
      expect(release_platform.errors.messages[:"production_release.submissions.integrable_type"])
        .to include("the production release submission must be to the primary app and not an app variant")
    end
  end
end
