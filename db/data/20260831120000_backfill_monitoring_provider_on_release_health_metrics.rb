# frozen_string_literal: true

# Metrics written before per-provider typing existed have a NULL monitoring_provider_type.
# Until multi-provider monitoring, an app could only have one monitoring integration and
# the fetch always went through the singular monitoring_provider, so the provider behind a
# legacy row is unambiguous: the app's primary (oldest kept) monitoring provider.
#
# Rows are left untyped when the app has no kept monitoring integration to infer from —
# the provider that wrote them is genuinely unknown at that point. Provider-scoped reads
# treat NULL as its own bucket, so those rows keep behaving exactly as they do today.
class BackfillMonitoringProviderOnReleaseHealthMetrics < ActiveRecord::Migration[7.2]
  def up
    App.find_each do |app|
      provider = app.monitoring_provider
      next if provider.blank?

      # Train is default-scoped to kept, and a discarded train's metrics need typing too.
      train_ids = Train.unscoped.where(app_id: app.id).select(:id)
      production_release_ids = ProductionRelease
        .joins(release_platform_run: :release)
        .where(releases: {train_id: train_ids})
        .select(:id)

      ReleaseHealthMetric
        .where(monitoring_provider_type: nil, production_release_id: production_release_ids)
        .in_batches(of: 5_000)
        .update_all(monitoring_provider_type: provider.class.name, monitoring_provider_id: provider.id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
