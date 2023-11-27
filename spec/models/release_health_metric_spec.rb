require "rails_helper"

describe ReleaseHealthMetric do
  it "has valid factory" do
    expect(create(:release_health_metric)).to be_valid
  end

  describe "#check_release_health" do
    let(:train) { create(:train) }
    let(:release) { create(:release, train:) }
    let(:step_run) { create(:step_run, release_platform_run: release.release_platform_runs.first) }
    let(:deployment_run) { create(:deployment_run, step_run:) }
    let(:healthy_metrics) {
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
    let(:healthy_metric) { deployment_run.release_health_metrics.create(**healthy_metrics) }
    let(:unhealthy_metrics) {
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
    let(:unhealthy_metric) { deployment_run.release_health_metrics.create(**unhealthy_metrics) }

    context "when no rules" do
      it "does nothing" do
        unhealthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(0)
      end
    end

    context "when rules are defined" do
      it "evaluates rules to check release health and create events when unhealthy" do
        user_stability_rule = create(:release_health_rule, :user_stability, train:)
        unhealthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(1)
        expect(deployment_run.release_health_events.first.release_health_rule).to eq(user_stability_rule)
      end

      it "evaluates rules to check release health and does not create events when healthy" do
        _user_stability_rule = create(:release_health_rule, :user_stability, train:)
        healthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(0)
      end

      it "creates health events for only the broken rules" do
        user_stability_rule = create(:release_health_rule, :user_stability, train:)
        _session_stability_rule = create(:release_health_rule, :session_stability, train:)
        unhealthy_metric.check_release_health

        expect(deployment_run.release_health_events.size).to eq(1)
        expect(deployment_run.release_health_events.first.release_health_rule).to eq(user_stability_rule)
      end
    end
  end
end
