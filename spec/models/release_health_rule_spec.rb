require "rails_helper"

describe ReleaseHealthRule do
  it "has valid factory" do
    expect(create(:release_health_rule, :session_stability)).to be_valid
  end

  describe "#healthy?" do
    let(:release_health_rule) { create(:release_health_rule) }
    let(:healthy_metric) { create(:release_health_metric, daily_users: 10, daily_users_with_errors: 1) }
    let(:unhealthy_metric) { create(:release_health_metric, daily_users: 10, daily_users_with_errors: 9) }

    it "returns true if trigger expression evaluation fails" do
      create(:trigger_rule_expression, release_health_rule:, metric: "user_stability", comparator: "lt", threshold_value: 90)
      expect(release_health_rule.healthy?(healthy_metric)).to be(true)
    end

    it "returns false if trigger expression evaluation fails" do
      create(:trigger_rule_expression, release_health_rule:, metric: "user_stability", comparator: "lt", threshold_value: 90)
      expect(release_health_rule.healthy?(unhealthy_metric)).to be(false)
    end

    it "returns true if trigger expression evaluation fails and filter expression evaluates to false" do
      create(:trigger_rule_expression, release_health_rule:, metric: "user_stability", comparator: "lt", threshold_value: 90)
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 50)
      expect(release_health_rule.healthy?(unhealthy_metric)).to be(true)
    end

    it "returns false if trigger expression evaluation fails and filter expression evaluates to true" do
      create(:trigger_rule_expression, release_health_rule:, metric: "user_stability", comparator: "lt", threshold_value: 90)
      create(:filter_rule_expression, release_health_rule:, metric: "adoption_rate", comparator: "gt", threshold_value: 0)
      expect(release_health_rule.healthy?(unhealthy_metric)).to be(false)
    end
  end
end
