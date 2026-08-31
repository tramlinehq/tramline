require "rails_helper"

describe ProductionRelease do # rubocop:disable RSpec/SpecFilePathFormat
  let(:train) { create(:train) }
  let(:release_platform) { create(:release_platform, train:) }
  let(:app) { train.app }

  let!(:crashlytics_integration) { create(:integration, :with_crashlytics, integrable: app) }
  let!(:sentry_integration) { create(:integration, :with_sentry, integrable: app) }
  let(:crashlytics_provider) { crashlytics_integration.providable }
  let(:sentry_provider) { sentry_integration.providable }

  let(:rollout_tree) do
    create_production_rollout_tree(
      train,
      release_platform,
      release_traits: [:on_track],
      run_status: :on_track,
      parent_release_status: :active,
      rollout_status: :started,
      skip_rollout: false
    )
  end
  let(:production_release) { rollout_tree[:production_release] }
  let(:store_rollout) { rollout_tree[:store_rollout] }

  let(:healthy_data) do
    {daily_users: 100, daily_users_with_errors: 1, errors_count: 2, new_errors_count: 0,
     sessions: 100, sessions_in_last_day: 50, sessions_with_errors: 1, total_sessions_in_last_day: 1000}
  end
  let(:unhealthy_data) do
    {daily_users: 100, daily_users_with_errors: 50, errors_count: 20, new_errors_count: 5,
     sessions: 100, sessions_in_last_day: 50, sessions_with_errors: 50, total_sessions_in_last_day: 1000}
  end

  describe "Integration#monitoring_providers" do
    it "returns all connected monitoring integrations" do
      providers = app.monitoring_providers
      expect(providers.size).to eq(2)
      expect(providers).to include(crashlytics_provider)
      expect(providers).to include(sentry_provider)
    end

    it "monitoring_provider (singular) still returns first provider" do
      expect(app.monitoring_provider).to be_present
    end
  end

  describe "ProductionRelease#fetch_health_data!" do
    it "stores monitoring_provider_type and id on the metric" do
      allow(crashlytics_provider).to receive(:find_release).and_return(healthy_data)

      production_release.fetch_health_data!(crashlytics_provider)

      metric = production_release.release_health_metrics.last
      expect(metric.monitoring_provider_type).to eq("CrashlyticsIntegration")
      expect(metric.monitoring_provider_id).to eq(crashlytics_provider.id)
    end

    it "creates separate metrics per provider" do
      allow(crashlytics_provider).to receive(:find_release).and_return(healthy_data)
      allow(sentry_provider).to receive(:find_release).and_return(unhealthy_data)

      production_release.fetch_health_data!(crashlytics_provider)
      production_release.fetch_health_data!(sentry_provider)

      metrics = production_release.release_health_metrics.reload
      expect(metrics.size).to eq(2)
      expect(metrics.pluck(:monitoring_provider_type)).to contain_exactly("CrashlyticsIntegration", "SentryIntegration")
    end
  end

  describe "ProductionRelease#latest_health_data_by_provider" do
    it "returns the latest metric per provider type" do
      production_release.release_health_metrics.create!(
        fetched_at: 10.minutes.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **healthy_data
      )
      production_release.release_health_metrics.create!(
        fetched_at: 5.minutes.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **unhealthy_data
      )
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )

      by_provider = production_release.latest_health_data_by_provider
      expect(by_provider.size).to eq(2)

      crashlytics_data = by_provider.find { |m| m.monitoring_provider_type == "CrashlyticsIntegration" }
      expect(crashlytics_data.daily_users_with_errors).to eq(50) # the latest one (unhealthy)

      sentry_data = by_provider.find { |m| m.monitoring_provider_type == "SentryIntegration" }
      expect(sentry_data.daily_users_with_errors).to eq(1) # healthy
    end
  end

  describe "Health events scoped by provider" do
    before do
      create(:release_health_rule, :user_stability, release_platform: production_release.release_platform)
    end

    it "does not let a healthy fetch from one provider overwrite an unhealthy event from another" do
      # Crashlytics reports unhealthy
      production_release.release_health_metrics.create!(
        fetched_at: 5.minutes.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **unhealthy_data
      )

      # Sentry reports healthy
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )

      events = production_release.release_health_events.reload
      crashlytics_events = events.joins(:release_health_metric)
        .where(release_health_metrics: {monitoring_provider_type: "CrashlyticsIntegration"})
      sentry_events = events.joins(:release_health_metric)
        .where(release_health_metrics: {monitoring_provider_type: "SentryIntegration"})

      expect(crashlytics_events.last).to be_unhealthy
      expect(sentry_events.last).to be_healthy
    end

    it "release is unhealthy when any provider is unhealthy" do
      production_release.release_health_metrics.create!(
        fetched_at: 5.minutes.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **unhealthy_data
      )
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )

      expect(production_release.reload).not_to be_healthy
    end

    it "release is healthy when all providers are healthy" do
      production_release.release_health_metrics.create!(
        fetched_at: 5.minutes.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **healthy_data
      )
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )

      expect(production_release.reload).to be_healthy
    end
  end

  # db/data/20260831120000 backfills the provider onto pre-typing rows, but a row can still
  # be untyped (written by old code mid-deploy, or an app with no monitoring integration
  # left to infer from), so nil has to keep behaving as its own provider bucket.
  describe "Untyped (nil-typed) metrics" do
    before do
      create(:release_health_rule, :user_stability, release_platform: production_release.release_platform)
    end

    it "keeps gating healthy? on an untyped unhealthy event while a typed secondary is healthy" do
      # Metric with no provider type on it, unhealthy.
      production_release.release_health_metrics.create!(
        fetched_at: 5.minutes.ago,
        monitoring_provider_type: nil,
        monitoring_provider_id: nil,
        **unhealthy_data
      )
      # A typed secondary provider (Sentry) lands first with healthy data.
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )

      expect(production_release.reload).not_to be_healthy
      expect(production_release.show_health?).to be(true)
    end

    it "show_health? stays true when the only fresh row is an untyped metric" do
      # Typed row exists but is stale (beyond the freshness window).
      production_release.release_health_metrics.create!(
        fetched_at: 40.days.ago,
        monitoring_provider_type: "SentryIntegration",
        monitoring_provider_id: sentry_provider.id,
        **healthy_data
      )
      # A fresh untyped row must still surface health.
      production_release.release_health_metrics.create!(
        fetched_at: 3.minutes.ago,
        monitoring_provider_type: nil,
        monitoring_provider_id: nil,
        **healthy_data
      )

      expect(production_release.show_health?).to be(true)
    end
  end

  describe "FetchHealthMetricsJob" do
    it "resolves provider by type and fetches from it" do
      allow(CrashlyticsIntegration).to receive(:find).with(crashlytics_provider.id).and_return(crashlytics_provider)
      allow_any_instance_of(CrashlyticsIntegration).to receive(:find_release).and_return(healthy_data) # rubocop:disable RSpec/AnyInstance

      FetchHealthMetricsJob.new.perform(production_release.id, 120.minutes, "CrashlyticsIntegration")

      metric = production_release.release_health_metrics.last
      expect(metric.monitoring_provider_type).to eq("CrashlyticsIntegration")
    end

    it "falls back to singular monitoring_provider when provider_type is nil" do
      allow_any_instance_of(CrashlyticsIntegration).to receive(:find_release).and_return(healthy_data) # rubocop:disable RSpec/AnyInstance

      FetchHealthMetricsJob.new.perform(production_release.id, 5.minutes, nil)

      metric = production_release.release_health_metrics.last
      expect(metric).to be_present
    end

    it "gracefully handles unknown provider_type" do
      expect {
        FetchHealthMetricsJob.new.perform(production_release.id, 5.minutes, "NonExistentIntegration")
      }.not_to raise_error

      expect(production_release.release_health_metrics.count).to eq(0)
    end

    it "always reschedules itself to maintain a continuous polling chain" do
      allow_any_instance_of(CrashlyticsIntegration).to receive(:find_release).and_return(healthy_data) # rubocop:disable RSpec/AnyInstance

      # Simulate a metric from a previous run of the same chain
      production_release.release_health_metrics.create!(
        fetched_at: 2.hours.ago,
        monitoring_provider_type: "CrashlyticsIntegration",
        monitoring_provider_id: crashlytics_provider.id,
        **healthy_data
      )

      FetchHealthMetricsJob.jobs.clear
      FetchHealthMetricsJob.new.perform(production_release.id, 120.minutes, "CrashlyticsIntegration")

      # Must reschedule — a single chain should keep running indefinitely
      expect(FetchHealthMetricsJob.jobs.size).to eq(1)
    end
  end
end
