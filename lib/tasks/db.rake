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
      prun.passports&.delete_all
      prun.release_metadata&.delete_all
      prun.store_rollouts&.delete_all
      prun.store_submissions&.delete_all
      prun.production_releases.each do |pr|
        pr.release_health_metrics&.delete_all
        pr.release_health_events&.delete_all
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
