require "data-anonymization"
require "faker"

namespace :anonymize do
  desc 'Anonymize release train data from source db into local db
        Example: rake "anonymize:release_train[ueno-staging-cross-platform,e735400a-3337-4699-95e2-c32b76ead7f3,ios]"'
  task :release_train, %i[internal_app_slug external_train_id platform] => [:destructive, :environment] do |_, args|
    DataAnon::Utils::Logging.logger.level = Logger::INFO

    app_slug = args[:internal_app_slug].to_s
    app = App.find_by slug: app_slug
    abort "App not found!" unless app

    platform = args[:platform].to_s
    abort "Platform not found!" if platform.blank?
    abort "Invalid platform" unless %w[ios android cross_platform].include?(platform)

    train_id = args[:external_train_id].to_s
    abort "Train ID not found!" if train_id.blank?
    puts "Train with id #{train_id} will be copied to #{app.name}!" if train_id.present?

    ci_cd_integration = app.integrations.ci_cd.first
    app_store_integration = app.integrations.build_channel.find(&:app_store_integration?)
    play_store_integration = app.integrations.build_channel.find(&:google_play_store_integration?)
    firebase_integration = app.integrations.build_channel.find(&:google_firebase_integration?)

    abort "App integrations not set up!" if app_store_integration.blank? && (app.cross_platform? || app.ios?)
    abort "App integrations not set up!" if play_store_integration.blank? && (app.cross_platform? || app.android?)
    abort "App integrations not set up!" if firebase_integration.blank? && app.android?

    ActiveRecord::Base.transaction do
      app.trains.each do |train|
        nuke_train(train)
      end
    end

    user_ids = app.organization.users.pluck(:id)
    user_github_logins = app.organization.users.pluck(:github_login)

    database "TramlineDatabase" do
      strategy DataAnon::Strategy::Whitelist
      source_db source_db_config
      destination_db destination_db_config

      table "trains" do
        skip { |index, record| record["id"] != train_id }

        primary_key "id"
        whitelist "name", "slug", "description", "status", "branching_strategy", "version_seeded_with", "version_current",
          "repeat_duration", "build_queue_wait_time", "build_queue_size", "backmerge_strategy", "manual_release",
          "tag_platform_releases", "tag_all_store_releases", "compact_build_notes", "tag_releases", "build_queue_enabled",
          "kickoff_at", "versioning_strategy", "send_build_notes", "notifications_enabled", "tag_suffix", "tag_platform_releases"
        whitelist_timestamps
        anonymize("app_id") { |field| app.id }
        anonymize("notification_channel") { |field| {"id" => "dummy", "name" => "test", "is_private" => false} }
        anonymize("working_branch") { |field| Faker::Hacker.noun }
      end

      table "release_indices" do
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "tolerable_range", "train_id"
        whitelist_timestamps
      end

      table "release_index_components" do
        continue { |index, record| ReleaseIndex.exists?(record["release_index_id"]) }

        primary_key "id"
        whitelist "name", "weight", "tolerable_range", "tolerable_unit", "release_index_id"
        whitelist_timestamps
      end

      table "notification_settings" do
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "train_id", "kind", "active", "user_groups"
        whitelist_timestamps
        anonymize("notification_channels") do |field|
          [{"id" => "dummy", "name" => "test", "is_private" => false}]
        end
      end

      table "release_platforms" do
        continue { |index, record| record["platform"] == platform || platform == "cross_platform" && Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "status", "name", "version_seeded_with", "version_current", "slug", "working_branch", "branching_strategy",
          "release_branch", "release_backmerge_branch", "vcs_webhook_id", "train_id", "platform"
        whitelist_timestamps
        anonymize("app_id") { |field| app.id }
      end

      table "release_health_rules" do
        continue { |index, record| ReleasePlatform.exists?(record["release_platform_id"]) }

        primary_key "id"
        whitelist "is_halting", "release_platform_id", "discarded_at"
        whitelist_timestamps
        anonymize("name") { |_| (Faker::Hacker.noun + " Rule").titleize }
      end

      table "rule_expressions" do
        continue { |index, record| ReleaseHealthRule.exists?(record["release_health_rule_id"]) }

        primary_key "id"
        whitelist "comparator", "metric", "threshold_value", "type", "release_health_rule_id"
        whitelist_timestamps
      end

      table "steps" do
        continue { |index, record| ReleasePlatform.exists?(record["release_platform_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "status", "step_number", "slug", "release_suffix", "kind", "auto_deploy", "app_variant_id", "discarded_at"
        whitelist_timestamps
        anonymize("ci_cd_channel") do |field|
          {"id" => "dummy", "name" => "CI Workflow #{Faker::JapaneseMedia::StudioGhibli.character}"}
        end
        anonymize("name").using FieldStrategy::LoremIpsum.new
        anonymize("description").using FieldStrategy::LoremIpsum.new
        anonymize("integration_id") do |field|
          ci_cd_integration.id
        end
      end

      table "deployments" do
        continue { |index, record| Step.exists?(record["step_id"]) }

        primary_key "id"
        whitelist "step_id", "build_artifact_channel", "deployment_number", "staged_rollout_config", "is_staged_rollout", "discarded_at"
        whitelist_timestamps
        anonymize("build_artifact_channel") do |field|
          step = Step.find(field.ar_record.step_id)
          if step.kind == "release"
            field.value
          else
            val = field.value
            val["name"] = Faker::TvShows::TwinPeaks.location
            val
          end
        end
        anonymize("integration_id") do |field|
          step = Step.find(field.ar_record.step_id)
          release_platform = ReleasePlatform.find(step.release_platform_id)
          if release_platform.platform == "android" && step.kind == "release"
            play_store_integration.id
          elsif release_platform.platform == "ios"
            app_store_integration.id
          else
            firebase_integration.id
          end
        end
      end

      table "scheduled_releases" do
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "train_id", "failure_reason", "is_success", "scheduled_at"
        whitelist_timestamps
      end

      table "releases" do
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "train_id", "branch_name", "status", "original_release_version", "release_version", "scheduled_at",
          "completed_at", "stopped_at", "is_automatic", "tag_name", "release_type", "hotfixed_from", "new_hotfix_branch", "internal_notes"
        whitelist_timestamps

        anonymize("release_pilot_id").using FieldStrategy::SelectFromList.new(user_ids)
      end

      table "build_queues" do
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_id", "scheduled_at", "applied_at", "is_active"
        whitelist_timestamps
      end

      table "release_changelogs" do
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "from_ref", "locale", "promo_text", "created_at", "updated_at", "release_id"
        whitelist_timestamps
        anonymize("commits") do |field|
          if field.value.blank?
            field.value
          else
            field.value.map do |commit|
              {"sha" => SecureRandom.uuid.split("-").join,
               "url" => "https://github.com/tramlinehq/ueno/commit/6149361ed3f70f5315b613e9e19ed699e3785700",
               "message" => Faker::Lorem.paragraph_by_chars(number: commit["message"].size),
               "parents" => [{"sha" => "dummy"}],
               "author_url" => "https://github.com/tramlinehq",
               "author_name" => Faker::Name.name,
               "author_login" => user_github_logins.sample,
               "author_timestamp" => commit["author_timestamp"]}
            end
          end
        end
      end

      table "commits" do
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "timestamp", "release_platform_run_id", "release_id", "build_queue_id", "backmerge_failure", "parents"
        whitelist_timestamps
        anonymize("commit_hash") { |field| SecureRandom.uuid.split("-").join }
        anonymize("message") { |field| Faker::Lorem.paragraph_by_chars(number: field.value.size) }
        anonymize("author_name") { |field| Faker::Name.name }
        anonymize("author_email").using FieldStrategy::RandomMailinatorEmail.new
        anonymize("author_login").using FieldStrategy::SelectFromList.new(user_github_logins)
        anonymize("url").using FieldStrategy::RandomUrl.new
      end

      table "pull_requests" do
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_platform_run_id", "number", "state", "phase", "source", "head_ref", "base_ref", "opened_at",
          "closed_at", "release_id", "commit_id", "source_id", "labels"
        whitelist_timestamps
        anonymize("title") { |field| Faker::Lorem.paragraph_by_chars(number: field.value.size) }
        anonymize("body") { |field| Faker::Lorem.paragraph_by_chars(number: field.value.size) }
        anonymize("url").using FieldStrategy::RandomUrl.new
      end

      table "release_platform_runs" do
        continue { |index, record| ReleasePlatform.exists?(record["release_platform_id"]) && Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "code_name", "scheduled_at", "commit_sha", "status", "branch_name",
          "release_version", "completed_at", "stopped_at", "original_release_version", "release_id",
          "tag_name", "in_store_resubmission", "last_commit_id", "play_store_blocked"
        whitelist_timestamps
      end

      table "release_metadata" do
        continue { |index, record| Release.exists?(record["release_id"]) && ReleasePlatformRun.exists?(record["release_platform_run_id"]) }

        primary_key "id"
        whitelist "release_platform_run_id", "locale", "created_at", "updated_at", "release_id"
        whitelist_timestamps
        anonymize("release_notes").using FieldStrategy::LoremIpsum.new
        anonymize("promo_text").using FieldStrategy::LoremIpsum.new
      end

      table "step_runs" do
        continue { |index, record| Step.exists?(record["step_id"]) && ReleasePlatformRun.exists?(record["release_platform_run_id"]) }

        primary_key "id"
        whitelist "step_id", "release_platform_run_id", "scheduled_at", "status", "commit_id", "build_version",
          "sign_required", "approval_status"
        whitelist_timestamps
        anonymize("ci_link").using FieldStrategy::RandomUrl.new
        anonymize("build_number").using FieldStrategy::FormattedStringNumber.new
      end

      table "external_builds" do
        continue { |index, record| StepRun.exists?(record["step_run_id"]) }

        primary_key "id"
        whitelist "metadata", "step_run_id"
        whitelist_timestamps
      end

      table "deployment_runs" do
        continue { |index, record| Deployment.exists?(record["deployment_id"]) && StepRun.exists?(record["step_run_id"]) }

        primary_key "id"
        whitelist "deployment_id", "step_run_id", "scheduled_at", "status", "initial_rollout_percentage", "failure_reason"
        whitelist_timestamps
      end

      table "external_releases" do
        continue { |index, record| DeploymentRun.exists?(record["deployment_run_id"]) }

        primary_key "id"
        whitelist "deployment_run_id", "name", "status", "added_at", "size_in_bytes", "external_id", "reviewed_at", "released_at"
        whitelist_timestamps
        anonymize("external_link").using FieldStrategy::RandomUrl.new
        anonymize("build_number").using FieldStrategy::FormattedStringNumber.new
      end

      table "staged_rollouts" do
        continue { |index, record| DeploymentRun.exists?(record["deployment_run_id"]) }
        primary_key "id"
        whitelist "deployment_run_id", "config", "status", "current_stage"
        whitelist_timestamps
      end

      table "passports" do
        continue { |index, record| record["stampable_type"].constantize.exists?(record["stampable_id"]) && !Passport.exists?(record["id"]) }

        primary_key "id"
        whitelist "stampable_type", "stampable_id", "reason", "kind", "message", "metadata", "author_id",
          "event_timestamp", "automatic"
        whitelist_timestamps
        anonymize("author_id").using FieldStrategy::SelectFromList.new(user_ids)
        anonymize("author_metadata") do |field|
          if field.value.blank?
            field.value
          else
            {
              name: Faker::Name.name,
              full_name: Faker::Name.name,
              role: "developer",
              email: FieldStrategy::RandomMailinatorEmail.new
            }
          end
        end
      end
    end

    app.releases.finished.each do |release|
      Queries::ReleaseSummary.warm(release.id)
    end
    train = app.trains.reload.find(train_id)
    Charts::DevopsReport.warm(train)

    train.release_platforms.each do |release_platform|
      populate_config(release_platform)
    end

    populate_v2_models(train)
  end

  desc 'Anonymize release health metric data from source db into local db
        Example: rake "anonymize:release_health_metrics[ueno-staging-cross-platform,e735400a-3337-4699-95e2-c32b76ead7f3]"'
  task :release_health_metrics, %i[internal_app_slug external_train_id] => [:destructive, :environment] do |_, args|
    DataAnon::Utils::Logging.logger.level = Logger::INFO

    app_slug = args[:internal_app_slug].to_s
    app = App.find_by slug: app_slug
    abort "App not found!" unless app

    train_id = args[:external_train_id].to_s
    abort "Train ID not found!" if train_id.blank?
    puts "Release health data for train with id #{train_id} will be copied to #{app.name}!" if train_id.present?

    train = app.trains.find(train_id)
    abort "Train not found!" unless train

    database "TramlineDatabase" do
      strategy DataAnon::Strategy::Whitelist
      source_db source_db_config
      destination_db destination_db_config

      table "release_health_metrics" do
        continue { |index, record| DeploymentRun.exists?(record["deployment_run_id"]) && !ReleaseHealthMetric.exists?(record["id"]) }
        primary_key "id"
        whitelist "deployment_run_id", "sessions", "sessions_in_last_day", "sessions_with_errors", "daily_users",
          "daily_users_with_errors", "errors_count", "new_errors_count", "fetched_at", "total_sessions_in_last_day", "external_release_id"
        whitelist_timestamps
      end

      table "release_health_events" do
        continue do |index, record|
          DeploymentRun.exists?(record["deployment_run_id"]) &&
            ReleaseHealthRule.exists?(record["release_health_rule_id"]) &&
            ReleaseHealthMetric.exists?(record["release_health_metric_id"]) &&
            !ReleaseHealthEvent.exists?(record["id"])
        end

        primary_key "id"
        whitelist "deployment_run_id", "release_health_rule_id", "release_health_metric_id", "health_status", "action_triggered", "notification_triggered", "event_timestamp"
        whitelist_timestamps
      end
    end

    populate_v2_metrics_models(train)
  end

  desc "Populate v2 models for the train"
  task :populate_v2_models, %i[external_train_id] => [:destructive, :environment] do |_, args|
    train_id = args[:external_train_id].to_s
    abort "Train ID not found!" if train_id.blank?

    train = Train.find(train_id)
    abort "Train not found!" unless train

    populate_v2_models(train)

    train.releases.finished.each do |release|
      release.release_platform_runs.each do |release_platform_run|
        Queries::PlatformBreakdown.warm(release_platform_run.id)
      end
      Queries::ReleaseBreakdown.warm(release.id)
    end

    Queries::DevopsReport.warm(train)
  end

  def source_db_config
    {"adapter" => "postgresql",
     "encoding" => "unicode",
     "pool" => 5,
     "host" => ENV["ANONYMIZE_SOURCE_DB_HOST"],
     "database" => ENV["ANONYMIZE_SOURCE_DB_NAME"],
     "user" => ENV["ANONYMIZE_SOURCE_DB_USER"],
     "password" => ENV["ANONYMIZE_SOURCE_DB_PASSWORD"]}
  end

  def destination_db_config
    Rails.configuration.database_configuration[Rails.env]
  end

  def whitelist_timestamps
    whitelist "created_at", "updated_at"
  end

  def populate_v2_models(train)
    ActiveRecord::Base.transaction do
      train.releases.where.not(is_v2: true).each do |release|
        release.update!(is_v2: true)
        release.release_platform_runs.each do |prun|
          prun.update!(config: prun.release_platform.config)

          review_step = prun.release_platform.steps.review.first
          review_runs = prun.step_runs_for(review_step).to_a
          review_step_run = review_runs.shift
          previous = nil
          idx = 0

          while review_step_run.present?
            pre_prod_release = create_pre_prod_release!(prun, review_step, review_step_run, previous, idx, "internal")
            previous = pre_prod_release
            review_step_run = review_runs.shift
            idx += 1
          end

          release_step = prun.release_platform.release_step
          release_step_runs = prun.step_runs_for(release_step).to_a

          release_step_run = release_step_runs.shift
          previous_pre_prod_release = nil
          previous_production_release = nil
          idx = 0
          production_release_config = prun.conf.production_release.value
          production_depl = release_step.deployments.find { |d| d.production_channel? }

          while release_step_run.present?
            pre_prod_release = create_pre_prod_release!(prun, release_step, release_step_run, previous_pre_prod_release, idx, "release_candidate")
            release_step_run.deployment_runs.where(deployment: production_depl).each do |drun|
              production_release = prun.production_releases.create!(
                id: drun.id,
                config: production_release_config,
                build: pre_prod_release.build,
                status: compute_production_release_status(release_step_run, idx),
                previous: previous_production_release,
                created_at: release_step_run.created_at,
                updated_at: release_step_run.updated_at
              )
              submission_config = prun.conf.production_release.submissions.first
              submission = submission_config.submission_type.create!(
                parent_release: production_release,
                release_platform_run: prun,
                build: pre_prod_release.build,
                sequence_number: 1,
                config: submission_config.to_h,
                status: "prepared",
                created_at: drun.created_at,
                updated_at: drun.updated_at
              )

              if drun.staged_rollout.present?
                if submission.is_a?(PlayStoreSubmission)
                  submission.create_play_store_rollout!(
                    release_platform_run: prun,
                    current_stage: drun.staged_rollout&.current_stage || 0,
                    config: submission_config.rollout_config.stages.presence || [],
                    is_staged_rollout: submission_config.rollout_config.enabled,
                    status: drun.staged_rollout.stopped? ? "halted" : drun.staged_rollout.status,
                    created_at: drun.staged_rollout.created_at,
                    updated_at: drun.staged_rollout.updated_at
                  )
                elsif submission.is_a?(AppStoreSubmission)
                  submission.create_app_store_rollout!(
                    release_platform_run: prun,
                    current_stage: drun.staged_rollout&.current_stage || 0,
                    config: submission_config.rollout_config.stages.presence || [],
                    is_staged_rollout: submission_config.rollout_config.enabled,
                    status: drun.staged_rollout.stopped? ? "halted" : drun.staged_rollout.status,
                    created_at: drun.staged_rollout.created_at,
                    updated_at: drun.staged_rollout.updated_at
                  )
                end
              end

              previous_pre_prod_release = pre_prod_release
              previous_production_release = production_release
              idx += 1
            end

            release_step_run = release_step_runs.shift
          end
        end
      end
    end
  end

  def populate_v2_metrics_models(train)
    ActiveRecord::Base.transaction do
      train.releases.where(is_v2: true).each do |release|
        release.deployment_runs.each do |drun|
          next unless ProductionRelease.exists?(drun.id)
          # rubocop:disable Rails/SkipsModelValidations
          drun.release_health_metrics.update_all(production_release_id: drun.id)
          # rubocop:enable Rails/SkipsModelValidations
        end
      end
    end
  end

  def create_pre_prod_release!(release_platform_run, step, step_run, previous, idx, kind)
    commit = step_run.commit
    status = compute_pre_prod_release_status(step_run, idx)

    if kind == "internal"
      config = release_platform_run.conf.internal_release
      pre_prod_release = release_platform_run.internal_releases.create!(config: config.value, commit:, status:, previous:)
      workflow_config = release_platform_run.conf.workflows.pick_internal_workflow
    else
      config = release_platform_run.conf.beta_release
      pre_prod_release = release_platform_run.beta_releases.create!(config: config.value, commit:, status:, previous:)
      workflow_config = release_platform_run.conf.workflows.release_candidate_workflow
    end

    workflow_run = WorkflowRun.create!(
      workflow_config: workflow_config.value,
      triggering_release: pre_prod_release,
      release_platform_run:,
      commit:,
      kind: workflow_config.kind,
      status: compute_workflow_run_status(step_run),
      created_at: step_run.created_at,
      updated_at: step_run.updated_at
    )

    build = workflow_run.create_build!(
      version_name: step_run.build_version,
      release_platform_run:,
      generated_at: step_run.build_artifact&.generated_at || step_run.scheduled_at,
      build_number: step_run.build_number,
      created_at: step_run.created_at,
      updated_at: step_run.updated_at,
      commit:
    )

    step.deployments.reject { |d| d.production_channel? }.each_with_index do |deployment, index|
      submission_config = config.submissions.fetch_by_number(index + 1)
      create_pre_prod_submissions(release_platform_run, step_run, deployment, submission_config, pre_prod_release, build)
    end
    pre_prod_release
  end

  def create_pre_prod_submissions(release_platform_run, step_run, deployment, config, parent_release, build)
    step_run.deployment_runs.where(deployment: deployment).each do |drun|
      submission = config.submission_type.create!(
        parent_release:,
        release_platform_run:,
        build:,
        sequence_number: config.number,
        config: config.to_h,
        status: drun.failed? ? "failed" : success_state(config.submission_type),
        created_at: drun.created_at,
        updated_at: drun.updated_at
      )

      if submission.is_a?(PlayStoreSubmission)
        submission.create_play_store_rollout!(
          release_platform_run:,
          config: config.rollout_config.stages.presence || [],
          is_staged_rollout: config.rollout_config.enabled,
          status: drun.failed? ? "failed" : "completed",
          created_at: drun.created_at,
          updated_at: drun.updated_at
        )
      end
    end
  end

  def compute_production_release_status(step_run, idx)
    if step_run.success?
      "finished"
    elsif step_run.deployment_started? && idx == 0
      "active"
    elsif step_run.active? && idx == 0
      "inflight"
    else
      "stale"
    end
  end

  def compute_pre_prod_release_status(step_run, idx)
    if step_run.success?
      "finished"
    elsif step_run.failed?
      "failed"
    elsif step_run.deployment_started? && idx == 0
      "created"
    else
      "stale"
    end
  end

  def compute_workflow_run_status(step_run)
    if step_run.ci_workflow_failed?
      "failed"
    elsif step_run.ci_workflow_halted?
      "halted"
    elsif step_run.ci_workflow_unavailable?
      "unavailable"
    elsif step_run.ci_workflow_started?
      "started"
    elsif step_run.ci_workflow_triggered?
      "triggered"
    else
      "finished"
    end
  end

  def success_state(submission_type)
    case submission_type.to_s
    when "PlayStoreSubmission"
      "prepared"
    when "AppStoreSubmission"
      "approved"
    when "TestFlightSubmission"
      "finished"
    when "GoogleFirebaseSubmission"
      "finished"
    else
      raise "Unknown submission type: #{submission_type}"
    end
  end
end
