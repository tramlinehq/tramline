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
      let(:step) { create(:releases_step, :with_deployment) }
      let(:valid_deployments) {
        [
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [1, 2], is_staged_rollout: true),
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [2, 2, 2, 2.1, 5, 6.11111, 7, 8.123123, 9, 100], is_staged_rollout: true),
          build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [], is_staged_rollout: false)
        ]
      }

      let!(:invalid_deployments) {
        [
          {deployment: build(:deployment, :with_google_play_store, step: step, staged_rollout_config: [1, 2], is_staged_rollout: true),
           error: {is_staged_rollout: ["only allowed for production channel"]}},
          {deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [0, 2], is_staged_rollout: true),
           error: {staged_rollout_config: ["cannot start with zero rollout"]}},
          {deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: [], is_staged_rollout: true),
           error: {staged_rollout_config: ["should have at least one rollout percentage value"]}},
          {deployment: build(:deployment, :with_google_play_store, :with_production_channel, step: step, staged_rollout_config: ["1.2", 1, "foo"], is_staged_rollout: true),
           error: {staged_rollout_config: ["staged rollout should be in increasing order"]}}
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
end
