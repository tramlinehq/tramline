require "rails_helper"

describe ReleaseHealthRule do
  it "has valid factory" do
    expect(create(:release_health_rule, :session_stability)).to be_valid
  end

  describe "#healthy?" do
    let(:production_release) { create(:production_release) }
    let(:release_health_rule) { create(:release_health_rule, :user_stability) }
    let(:healthy_metric) { create(:release_health_metric, daily_users: 10, daily_users_with_errors: 1, production_release:) }
    let(:unhealthy_metric) { create(:release_health_metric, daily_users: 10, daily_users_with_errors: 9, production_release:) }

    it "returns true if trigger expression evaluation fails" do
      expect(release_health_rule.healthy?(healthy_metric)).to be(true)
    end

    it "returns false if trigger expression evaluation passes" do
      expect(release_health_rule.healthy?(unhealthy_metric)).to be(false)
    end

    it "returns true if trigger expression evaluation fails and filter expression evaluates to false" do
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 50)
      expect(release_health_rule.reload.healthy?(unhealthy_metric)).to be(true)
    end

    it "returns false if trigger expression evaluation fails and filter expression evaluates to true" do
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 0)
      expect(release_health_rule.reload.healthy?(unhealthy_metric)).to be(false)
    end

    it "returns true if trigger expression evaluation fails and any filter expressions evaluate to false" do
      submission = create(:play_store_submission, :preparing, parent_release: production_release)
      create(:store_rollout, :started, store_submission: submission, config: [1, 10, 20, 50, 100], current_stage: 2)
      create(:filter_rule_expression, release_health_rule:, metric: "staged_rollout", comparator: "gt", threshold_value: 50)
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 0)
      expect(release_health_rule.reload.healthy?(unhealthy_metric)).to be(true)
    end

    it "returns false if trigger expression evaluation fails and all filter expressions evaluate to true" do
      submission = create(:play_store_submission, :preparing, parent_release: production_release)
      create(:store_rollout, :started, store_submission: submission, config: [1, 10, 20, 50, 100], current_stage: 2)
      create(:filter_rule_expression, release_health_rule:, metric: "staged_rollout", comparator: "gt", threshold_value: 10)
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 0)
      expect(release_health_rule.reload.healthy?(unhealthy_metric)).to be(false)
    end
  end
end
