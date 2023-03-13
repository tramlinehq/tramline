require "rails_helper"

describe Deployment do
  it "has a valid factory" do
    expect(create(:deployment, :with_step)).to be_valid
  end

  describe "#create" do
    it "adds incremented deployment numbers" do
      step = create(:releases_step, :with_deployment)
      d1 = create(:deployment, step: step)
      d2 = create(:deployment, step: step)

      expect(d1.deployment_number).to eq(2)
      expect(d2.deployment_number).to eq(3)
    end
  end

  describe "validations" do
    context "with staged rollout" do
      let(:step) { create(:releases_step, :release, :with_deployment) }
      let(:valid_deployments) {
        [
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [1, 2], is_staged_rollout: true),
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [2, 2, 2, 2.1, 5, 6.11111, 7, 8.123123, 9, 100], is_staged_rollout: true),
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [], is_staged_rollout: false),
          build(:deployment, :with_app_store, :with_production_channel, step: step, staged_rollout_config: [], is_staged_rollout: false)
        ]
      }

      let!(:invalid_deployments) {
        [
          {
            deployment: build(:deployment, :with_google_play_store, step: step, staged_rollout_config: [1, 2], is_staged_rollout: true),
            error: {is_staged_rollout: ["only allowed for production channel"]}
          },
          {
            deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [0, 2], is_staged_rollout: true),
            error: {staged_rollout_config: ["cannot start with zero rollout"]}
          },
          {
            deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [], is_staged_rollout: true),
            error: {staged_rollout_config: ["should have at least one rollout percentage value"]}
          },
          {
            deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: ["1.2", 1, "foo"], is_staged_rollout: true),
            error: {staged_rollout_config: ["staged rollout should be in increasing order"]}
          },
          {
            deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [1, "a", 0], is_staged_rollout: true),
            error: {staged_rollout_config: ["staged rollout should be in increasing order"]}
          },
          {
            deployment: build(:deployment, :with_app_store, :with_production_channel, step: step, staged_rollout_config: [1, 2], is_staged_rollout: true),
            error: {staged_rollout_config: ["staged rollout config is not allowed"]}
          }
        ]
      }

      it "works for valid staged rollout configs" do
        expect(valid_deployments).to all(be_valid)
      end

      it "fails for invalid staged rollout configs" do
        invalid_deployments.each do |invalid|
          expect(invalid[:deployment]).not_to be_valid
          expect(invalid[:deployment].errors.messages).to eq(invalid[:error])
        end
      end
    end
  end

  describe "#set_default_staged_rollout" do
    it "sets app store default rollout sequence" do
      step = create(:releases_step, :release, :with_deployment)
      app_store_deployment = create(:deployment, :with_app_store, :with_phased_release, step: step)

      expect(app_store_deployment.staged_rollout_config).to eq(AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE)
    end

    it "does not set app store default rollout sequence if not app store" do
      step = create(:releases_step, :release, :with_deployment)
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step)

      expect(deployment.staged_rollout_config).not_to eq(AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE)
    end
  end

  describe "#uploadable?" do
    it "is true when app is android and deployment is slack, google or external" do
      step = create(:releases_step, :with_deployment)
      d1 = create(:deployment, :with_google_play_store, step: step)
      d2 = create(:deployment, :with_slack, step: step)
      d3 = create(:deployment, :with_external, step: step)

      expect(d1.uploadable?).to be(true)
      expect(d2.uploadable?).to be(true)
      expect(d3.uploadable?).to be(true)
    end

    it "is false when app is ios and deployment is app store" do
      step = create(:releases_step, :with_deployment)
      deployment = create(:deployment, :with_app_store, step: step)

      expect(deployment.uploadable?).to be(false)
    end
  end

  describe "#findable?" do
    it "is false when app is android and deployment is slack, google or external" do
      step = create(:releases_step, :with_deployment)
      d1 = create(:deployment, :with_google_play_store, step: step)
      d2 = create(:deployment, :with_slack, step: step)
      d3 = create(:deployment, :with_external, step: step)

      expect(d1.findable?).to be(false)
      expect(d2.findable?).to be(false)
      expect(d3.findable?).to be(false)
    end

    it "is false when app is ios and deployment is app store" do
      deployment = create(:deployment, :with_step, :with_app_store)

      expect(deployment.findable?).to be(true)
    end
  end
end
