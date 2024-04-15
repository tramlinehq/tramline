require "rails_helper"

describe ReleaseHealthMetric do
  it "has valid factory" do
    expect(create(:release_health_metric)).to be_valid
  end

  describe "#check_release_health" do
    let(:deployment_run_tree) { create_deployment_run_tree(:android) }
    let(:deployment_run) { deployment_run_tree[:deployment_run] }
    let(:healthy_metrics_data) {
      {daily_users: 100,
       daily_users_with_errors: 1,
       errors_count: 2,
       new_errors_count: 0,
       fetched_at: Time.current,
       sessions: 100,
       sessions_in_last_day: 50,
       sessions_with_errors: 1,
       total_sessions_in_last_day: 1000}
    }
    let(:healthy_metric) { deployment_run.release_health_metrics.create(**healthy_metrics_data) }
    let(:unhealthy_metrics_data) {
      {daily_users: 100,
       daily_users_with_errors: 11,
       errors_count: 2,
       new_errors_count: 0,
       fetched_at: Time.current,
       sessions: 100,
       sessions_in_last_day: 50,
       sessions_with_errors: 1,
       total_sessions_in_last_day: 1000}
    }
    let(:unhealthy_metric) { deployment_run.release_health_metrics.create(**unhealthy_metrics_data) }

    context "when no rules" do
      it "does nothing" do
        expect { unhealthy_metric.check_release_health }.not_to change { deployment_run.release_health_events.reload.size }
      end
    end

    context "when rules are defined" do
      it "does nothing if rules are not actionable" do
        user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        create(:filter_rule_expression, release_health_rule: user_stability_rule, metric: "adoption_rate", comparator: "gt", threshold_value: 50)

        expect { unhealthy_metric.check_release_health }.not_to change { deployment_run.release_health_events.reload.size }
      end

      it "creates events if rules are actionable" do
        user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        create(:filter_rule_expression, release_health_rule: user_stability_rule, metric: "adoption_rate", comparator: "gt", threshold_value: 1)

        expect { unhealthy_metric.check_release_health }.to change { deployment_run.release_health_events.reload.size }.by(1)
      end

      it "evaluates rules to check release health and create events when unhealthy" do
        user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        unhealthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(1)
        expect(deployment_run.release_health_events.first.release_health_rule).to eq(user_stability_rule)
      end

      it "evaluates rules to check release health and creates events when healthy and no previous event" do
        _user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        healthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(1)
      end

      it "creates health events for all new rules" do
        user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        session_stability_rule = create(:release_health_rule, :session_stability, release_platform: deployment_run.release_platform)
        unhealthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(2)
        expect(deployment_run.release_health_events.first.release_health_rule).to eq(user_stability_rule)
        expect(deployment_run.release_health_events.second.release_health_rule).to eq(session_stability_rule)
      end

      it "creates health event when health goes from unhealthy to healthy" do
        _user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        _existing_metric = deployment_run.release_health_metrics.create!(**unhealthy_metrics_data)
        healthy_metric.check_release_health

        expect(deployment_run.release_health_events.reload.size).to eq(2)
        expect(deployment_run.release_health_events.reload.last.healthy?).to be(true)
      end

      it "creates health event when health goes from healthy to unhealthy" do
        _user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        _existing_metric = deployment_run.release_health_metrics.create!(**healthy_metrics_data)

        expect { unhealthy_metric.check_release_health }.to change { deployment_run.release_health_events.reload.size }.by(1)
        expect(deployment_run.release_health_events.reload.last.unhealthy?).to be(true)
      end

      it "does nothing when health does not change" do
        _user_stability_rule = create(:release_health_rule, :user_stability, release_platform: deployment_run.release_platform)
        _existing_metric = deployment_run.release_health_metrics.create!(**unhealthy_metrics_data)

        expect { unhealthy_metric.check_release_health }.not_to change { deployment_run.release_health_events.reload.size }
        expect(deployment_run.release_health_events.reload.last.unhealthy?).to be(true)
      end
    end
  end

  describe "#metric_healthy?" do
    let(:deployment_run_tree) { create_deployment_run_tree(:android) }
    let(:deployment_run) { deployment_run_tree[:deployment_run] }
    let(:release_platform) { deployment_run_tree[:release_platform] }

    it "raises ArgumentError when invalid metric name" do
      expect { create(:release_health_metric).metric_healthy?("invalid") }.to raise_error(ArgumentError, "Invalid metric name")
    end

    it "returns nil when no rules" do
      expect(create(:release_health_metric).metric_healthy?("session_stability")).to be_nil
    end

    it "returns true when all rules are healthy" do
      create(:release_health_rule, :user_stability, release_platform:)
      metric = create(:release_health_metric, daily_users: 100, daily_users_with_errors: 0, deployment_run:)
      expect(metric.reload.metric_healthy?("user_stability")).to be(true)
    end

    it "returns false when any rule is unhealthy" do
      create(:release_health_rule, :user_stability, release_platform:)
      metric = create(:release_health_metric, daily_users: 100, daily_users_with_errors: 99, deployment_run:)
      expect(metric.reload.metric_healthy?("user_stability")).to be(false)
    end

    it "returns true when rule is unhealthy but the trigger is healthy" do
      release_health_rule = create(:release_health_rule, :user_stability, release_platform:)
      create(:trigger_rule_expression, :session_stability, release_health_rule:)
      metric = create(:release_health_metric, deployment_run:, daily_users: 100, daily_users_with_errors: 1, sessions_with_errors: 90, sessions: 100)

      expect(metric.reload.metric_healthy?("user_stability")).to be(true)
      expect(metric.reload.metric_healthy?("session_stability")).to be(false)
    end
  end
end
