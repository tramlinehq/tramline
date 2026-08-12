namespace :db do
  desc "Nuke everything except users, organizations and apps"
  task nuke: [:destructive, :environment] do
    BuildArtifact.delete_all
    Commit.delete_all
    ReleasePlatformRun.delete_all
    ReleasePlatform.delete_all
    Release.delete_all
    Train.delete_all

    puts "Data was nuked!"
  end

  desc "Nuke the train and its entire tree"
  task :nuke_train, %i[train_id] => [:destructive, :environment] do |_, args|
    train_id = args[:train_id].to_s
    train = Train.find_by(id: train_id)
    abort "Train not found!" unless train

    ActiveRecord::Base.transaction do
      nuke_train(train)
    end

    puts "Train successfully deleted!"
  end

  desc "Nuke the app and its entire tree"
  task :nuke_app, %i[app_slug] => [:destructive, :environment] do |_, args|
    app_slug = args[:app_slug].to_s
    app = App.find_by slug: app_slug
    abort "App not found!" unless app

    ActiveRecord::Base.transaction do
      nuke_app(app)
    end

    puts "App successfully deleted!"
  end

  def nuke_app(app)
    app.trains.each { |train| nuke_train(train) }
    # integrations are polymorphic (integrable) with a separate providable row;
    # delete_all skips callbacks, so drop the provider rows explicitly first.
    app.integrations.includes(:providable).each { |i| i.providable&.delete }
    app.integrations.delete_all
    app.external_apps.delete_all
    app.variants.delete_all
    # `has_one :config` is commented out on App, so clear app_configs by FK.
    AppConfig.where(app_id: app.id).delete_all
    # Any release_platforms not reached via a train (e.g. app has 0 trains but
    # still carries platforms with configs) — tear each down before deleting.
    app.release_platforms.reload.each { |rp| nuke_release_platform(rp) }
    # Detach the icon in the DB only — do NOT purge. The GCS object lives in a
    # bucket shared with Render staging; purging would delete it there too.
    ActiveStorage::Attachment.where(record_type: "App", record_id: app.id).delete_all
    app.delete
  end

  # Nuke an org and everything under it: its apps (full tree), then the org's
  # own children (memberships incl. discarded, teams, invites, custom storage).
  def nuke_org(org)
    org.apps.each { |app| nuke_app(app) }
    Accounts::Membership.where(organization_id: org.id).delete_all
    org.teams.delete_all
    org.invites.delete_all
    Accounts::CustomStorage.where(organization_id: org.id).delete_all
    org.delete
  end

  # One-off targeted cleanup. Slugs via env (comma-separated); dry-run unless
  # CONFIRM=yes. Everything runs in one transaction, so a dry run validates the
  # entire delete against real data and then rolls back.
  #   APP_SLUGS=a,b ORG_SLUGS=c bin/rails db:nuke_targets            # dry run
  #   APP_SLUGS=a,b ORG_SLUGS=c CONFIRM=yes bin/rails db:nuke_targets # execute
  desc "Delete apps/orgs by slug (APP_SLUGS/ORG_SLUGS env). Dry-run unless CONFIRM=yes."
  task nuke_targets: :environment do
    dry = ENV["CONFIRM"] != "yes"
    app_slugs = ENV.fetch("APP_SLUGS", "").split(",").map(&:strip).reject(&:blank?)
    org_slugs = ENV.fetch("ORG_SLUGS", "").split(",").map(&:strip).reject(&:blank?)
    abort "Nothing to do: set APP_SLUGS and/or ORG_SLUGS" if app_slugs.empty? && org_slugs.empty?

    ActiveRecord::Base.transaction do
      # Disable FK enforcement for THIS transaction only (SET LOCAL auto-resets
      # on commit/rollback, so the pooled connection isn't left mutated). The
      # delete tree spans legacy tables without dependent: :destroy and migrated
      # data has orphaned execution rows; this frees us from exact FK ordering.
      # Safe because everything runs in one atomic transaction — a dry run
      # rolls the whole thing back, FK state included.
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")

      app_slugs.each do |slug|
        app = App.find_by(slug:)
        next puts("APP  #{slug}: NOT FOUND") unless app
        puts "APP  #{slug} (#{app.name}) org=#{app.organization.slug} trains=#{app.trains.count} releases=#{app.releases.count} -> delete"
        nuke_app(app)
      end
      org_slugs.each do |slug|
        org = Accounts::Organization.find_by(slug:)
        next puts("ORG  #{slug}: NOT FOUND") unless org
        puts "ORG  #{slug} (#{org.name}) apps=[#{org.apps.map(&:slug).join(", ")}] -> delete org + its apps"
        nuke_org(org)
      end

      if dry
        puts "\nDRY RUN — no changes committed (set CONFIRM=yes to execute)."
        raise ActiveRecord::Rollback
      else
        puts "\nCOMMITTED."
      end
    end
  end
end

def nuke_train(train)
  train.releases.each do |run|
    run.release_platform_runs.each do |prun|
      sql = "delete from external_releases where deployment_run_id IN (SELECT id FROM deployment_runs WHERE step_run_id IN (SELECT id FROM step_runs WHERE release_platform_run_id = '#{prun.id}'))"
      ActiveRecord::Base.connection.execute(sql)
      sql = "delete from staged_rollouts where deployment_run_id IN (SELECT id FROM deployment_runs WHERE step_run_id IN (SELECT id FROM step_runs WHERE release_platform_run_id = '#{prun.id}'))"
      ActiveRecord::Base.connection.execute(sql)
      sql = "delete from deployment_runs where step_run_id IN (SELECT id FROM step_runs WHERE release_platform_run_id = '#{prun.id}')"
      ActiveRecord::Base.connection.execute(sql)
      sql = "delete from step_runs where release_platform_run_id = '#{prun.id}'"
      ActiveRecord::Base.connection.execute(sql)
      prun.passports&.delete_all
      prun.release_metadata&.delete_all
      prun.store_rollouts&.delete_all
      prun.store_submissions&.delete_all
      prun.production_releases.each do |pr|
        pr.release_health_events&.delete_all
        pr.release_health_metrics&.delete_all
      end
      prun.production_releases&.delete_all
      prun.builds.each do |build|
        build.external_build&.delete
      end
      prun.builds.delete_all
      prun.workflow_runs&.delete_all
      prun.internal_releases&.delete_all
      prun.beta_releases&.delete_all
    end
    run.approval_items.each do |approval_item|
      approval_item.approval_assignees&.delete_all
    end
    run.approval_items&.delete_all
    run.pull_requests&.delete_all
    run.release_platform_runs&.delete_all
    run.all_commits.each do |commit|
      commit.passports&.delete_all
    end
    run.all_commits&.delete_all
    run.release_changelog&.commits&.delete_all
    run.release_changelog&.delete
    run.build_queues&.delete_all
    run.passports&.delete_all
  end
  train.releases&.delete_all
  train.scheduled_releases&.delete_all
  train.release_index&.components&.delete_all
  train.release_index&.delete
  train.release_index&.release_index_components&.delete_all
  train.release_index&.delete
  train.release_platforms.each { |release_platform| nuke_release_platform(release_platform) }
  train.notification_settings&.delete_all
  train.delete
end

# Tear down a single release_platform and everything hanging off it (steps,
# deployments, platform config + its workflows/releases/submissions, health
# rules, commit listeners), then delete the platform row itself. Shared by
# nuke_train and nuke_app so app-level platforms with no train are handled too.
def nuke_release_platform(release_platform)
  rid = release_platform.id
  c = ActiveRecord::Base.connection
  # Legacy execution subtree tied to this platform — reachable via its runs
  # (release_platform_runs → step_runs → deployment_runs) and via its config
  # (steps → deployments → deployment_runs). Migrated data can leave these
  # orphaned even for 0-release apps. FK enforcement is disabled for the
  # transaction (see nuke_targets), so order is forgiving.
  rpr = "SELECT id FROM release_platform_runs WHERE release_platform_id = '#{rid}'"
  sr  = "SELECT id FROM step_runs WHERE release_platform_run_id IN (#{rpr})"
  dep = "SELECT id FROM deployments WHERE step_id IN (SELECT id FROM steps WHERE release_platform_id = '#{rid}')"
  dr  = "SELECT id FROM deployment_runs WHERE step_run_id IN (#{sr}) OR deployment_id IN (#{dep})"
  c.execute("delete from external_releases where deployment_run_id IN (#{dr})")
  c.execute("delete from staged_rollouts where deployment_run_id IN (#{dr})")
  c.execute("delete from deployment_runs where step_run_id IN (#{sr}) OR deployment_id IN (#{dep})")
  c.execute("delete from step_runs where release_platform_run_id IN (#{rpr})")
  c.execute("delete from deployments where step_id IN (SELECT id FROM steps WHERE release_platform_id = '#{rid}')")
  c.execute("delete from steps where release_platform_id = '#{rid}'")
  # Config subtree (workflows + params, release steps + submissions + externals)
  # is fully dependent: :destroy — one destroy cascades all of it.
  release_platform.platform_config&.destroy
  release_platform.all_release_health_rules.each do |rule|
    rule.trigger_rule_expressions&.delete_all
    rule.filter_rule_expressions&.delete_all
  end
  release_platform.all_release_health_rules&.delete_all
  c.execute("delete from commit_listeners where release_platform_id = '#{rid}'")
  # Commits can reference the platform directly (fetched by commit listeners).
  platform_commits = Commit.where(release_platform_id: rid)
  platform_commits.each { |cm| cm.passports&.delete_all }
  platform_commits.delete_all
  c.execute("delete from release_platform_runs where release_platform_id = '#{rid}'")
  release_platform.delete
end
