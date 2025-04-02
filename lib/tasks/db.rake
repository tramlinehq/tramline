namespace :db do
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

  desc "Clear all database tables"
  task clear_db_tables: [:environment] do
    clear_database_tables
    puts "Database cleared for demo!"
  end

  def clear_database_tables
    # Get tables from schema.rb
    tables_to_clear = extract_tables_from_schema

    # Disable referential integrity to allow deleting from all tables
    ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica';")

    begin
      ActiveRecord::Base.transaction do
        tables_to_clear.each do |table|
          clear_data_from_table(table)
        end
      end
    ensure
      # Re-enable referential integrity
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin';")
    end
  end

  def extract_tables_from_schema
    schema_file = Rails.root.join("db/schema.rb")
    schema_content = File.read(schema_file)
    tables = []

    schema_content.scan(/create_table "([^"]+)"/) do |match|
      tables << match[0]
    end

    tables
  end

  def clear_data_from_table(table_name)
    begin
      sql = "DELETE FROM #{table_name}"
      ActiveRecord::Base.connection.execute(sql)
      puts "  Cleared table: #{table_name}"
    rescue => e
      puts "  Warning: Could not clear table #{table_name}: #{e.message}"
    end
  end

  def nuke_app(app)
    app.config.delete
    app.external_apps.delete_all
    app.integrations.delete_all
    app.trains.each do |train|
      nuke_train(train)
    end
    app.delete
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
  train.release_platforms.each do |release_platform|
    sql = "delete from deployments where step_id IN (SELECT id FROM steps WHERE release_platform_id = '#{release_platform.id}')"
    ActiveRecord::Base.connection.execute(sql)
    sql = "delete from steps where release_platform_id = '#{release_platform.id}'"
    ActiveRecord::Base.connection.execute(sql)
    config = release_platform.platform_config
    if config.present?
      config.internal_workflow&.delete
      config.release_candidate_workflow&.delete
      config.internal_release&.submissions&.each do |submission|
        submission.submission_external&.delete
        submission.delete
      end
      config.beta_release&.submissions&.each do |submission|
        submission.submission_external&.delete
        submission.delete
      end
      config.production_release&.submissions&.each do |submission|
        submission.submission_external&.delete
        submission.delete
      end
      config.internal_release&.delete
      config.beta_release&.delete
      config.production_release&.delete
      config.delete
    end
    release_platform.all_release_health_rules.each do |rule|
      rule.trigger_rule_expressions&.delete_all
      rule.filter_rule_expressions&.delete_all
    end
    release_platform.all_release_health_rules&.delete_all
    sql = "delete from commit_listeners where release_platform_id = '#{release_platform.id}'"
    ActiveRecord::Base.connection.execute(sql)
  end
  train.release_platforms&.delete_all
  train.notification_settings&.delete_all
  train.delete
end
