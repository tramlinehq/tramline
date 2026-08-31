# frozen_string_literal: true

# Metrics written before per-provider typing existed have a NULL monitoring_provider_type.
# Until multi-provider monitoring, the fetch always went through the singular
# monitoring_provider — the oldest monitoring integration that was connected at the time —
# so a legacy row can be attributed by replaying that rule against integration history.
#
# Integrations are walked oldest-first, each claiming the untyped rows fetched within its
# own lifetime; because a claimed row is no longer NULL, an older integration that was
# still connected always wins over a newer one, which is exactly what the old code did.
# Rows outside every integration's lifetime are left untyped: the provider that wrote them
# is genuinely unknown, and provider-scoped reads already treat NULL as its own bucket.
class BackfillMonitoringProviderOnReleaseHealthMetrics < ActiveRecord::Migration[7.2]
  def up
    App.find_each do |app|
      # Discarded integrations included on purpose — a replaced provider still wrote its rows.
      Integration.monitoring.where(integrable: app).order(:created_at).each do |integration|
        provider = integration.providable
        next if provider.blank?

        untyped_metrics_for(app)
          .where(fetched_at: integration.created_at...integration.discarded_at)
          .in_batches(of: 5_000)
          .update_all(monitoring_provider_type: provider.class.name, monitoring_provider_id: provider.id)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def untyped_metrics_for(app)
    # Train is default-scoped to kept, and a discarded train's metrics need typing too.
    train_ids = Train.unscoped.where(app_id: app.id).select(:id)
    production_release_ids = ProductionRelease
      .joins(release_platform_run: :release)
      .where(releases: {train_id: train_ids})
      .select(:id)

    ReleaseHealthMetric.where(monitoring_provider_type: nil, production_release_id: production_release_ids)
  end
end
