require "data-anonymization"
require "faker"

namespace :anonymize do
  desc 'Anonymize release train data from source db into local db;
        Example: rake "anonymize:release_train[ueno-staging-cross-platform,e735400a-3337-4699-95e2-c32b76ead7f3]"'
  task :release_train, %i[app_slug train_id] => [:destructive, :environment] do |_, args|
    DataAnon::Utils::Logging.logger.level = Logger::INFO

    app_slug = args[:app_slug].to_s
    app = App.find_by slug: app_slug
    abort "App not found!" unless app

    train_id = args[:train_id].to_s
    abort "Train ID not found!" if train_id.blank?
    puts "Train with id #{train_id} will be copied to #{app.name}!" if train_id.present?

    app_store_integration = app.integrations.build_channel.find(&:app_store_integration?)
    play_store_integration = app.integrations.build_channel.find(&:google_play_store_integration?)
    firebase_integration = app.integrations.build_channel.find(&:google_firebase_integration?)

    abort "App integrations not set up!" if app_store_integration.blank? || play_store_integration.blank? || firebase_integration.blank?

    ActiveRecord::Base.transaction do
      app.trains.each do |train|
        nuke_train(train)
      end
    end

    user_ids = app.organization.users.pluck(:id)

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
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "status", "name", "version_seeded_with", "version_current", "slug", "working_branch", "branching_strategy",
          "release_branch", "release_backmerge_branch", "vcs_webhook_id", "train_id", "platform"
        whitelist_timestamps
        anonymize("app_id") { |field| app.id }
      end

      table "steps" do
        continue { |index, record| ReleasePlatform.exists?(record["release_platform_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "status", "step_number", "slug", "release_suffix", "kind", "auto_deploy", "app_variant_id"
        whitelist_timestamps
        anonymize("ci_cd_channel") do |field|
          {"id" => "dummy", "name" => "CI Workflow #{Faker::JapaneseMedia::StudioGhibli.character}"}
        end
        anonymize("name").using FieldStrategy::LoremIpsum.new
        anonymize("description").using FieldStrategy::LoremIpsum.new
      end

      table "deployments" do
        continue { |index, record| Step.exists?(record["step_id"]) }

        primary_key "id"
        whitelist "step_id", "build_artifact_channel", "deployment_number", "staged_rollout_config", "is_staged_rollout", "discarded_at"
        whitelist_timestamps
        anonymize("build_artifact_channel") do |field|
          val = field.value
          val["name"] = Faker::TvShows::TwinPeaks.location if val["is_production"] != true
          val
        end
        anonymize("integration_id") do |field|
          step = Step.find(field.ar_record.step_id)
          release_platform = ReleasePlatform.find(step.release_platform_id)
          if release_platform.platform == "android" && field.ar_record.build_artifact_channel["is_production"] == true
            play_store_integration.id
          elsif release_platform.platform == "ios"
            app_store_integration.id
          else
            firebase_integration.id
          end
        end
      end

      table "releases" do
        continue { |index, record| Train.exists?(record["train_id"]) }

        primary_key "id"
        whitelist "train_id", "branch_name", "status", "original_release_version", "release_version", "scheduled_at",
          "completed_at", "stopped_at", "is_automatic", "tag_name", "release_type", "hotfixed_from", "new_hotfix_branch"
        whitelist_timestamps
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
               "message" => Faker::Company.bs,
               "parents" => [{"sha" => "dummy"}],
               "author_url" => "https://github.com/tramlinehq",
               "author_name" => Faker::Name.name,
               "author_login" => Faker::Twitter.screen_name,
               "author_timestamp" => commit["author_timestamp"]}
            end
          end
        end
      end

      table "commits" do
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "timestamp", "release_platform_run_id", "release_id", "build_queue_id", "backmerge_failure"
        whitelist_timestamps
        anonymize("commit_hash") { |field| SecureRandom.uuid.split("-").join }
        anonymize("message") { |field| Faker::Lorem.paragraph_by_chars(number: field.value.size) }
        anonymize("author_name") { |field| Faker::Name.name }
        anonymize("author_email").using FieldStrategy::RandomMailinatorEmail.new
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
        continue { |index, record| Release.exists?(record["release_id"]) }

        primary_key "id"
        whitelist "release_platform_id", "code_name", "scheduled_at", "commit_sha", "status", "branch_name",
          "release_version", "completed_at", "stopped_at", "original_release_version", "release_id",
          "tag_name", "in_store_resubmission", "last_commit_id"
        whitelist_timestamps
      end

      table "release_metadata" do
        continue { |index, record| Release.exists?(record["release_id"]) }
        continue { |index, record| ReleasePlatformRun.exists?(record["release_platform_run_id"]) }

        primary_key "id"
        whitelist "release_platform_run_id", "locale", "created_at", "updated_at", "release_id"
        whitelist_timestamps
        anonymize("release_notes").using FieldStrategy::LoremIpsum.new
        anonymize("promo_text").using FieldStrategy::LoremIpsum.new
      end

      table "step_runs" do
        continue { |index, record| ReleasePlatformRun.exists?(record["release_platform_run_id"]) }
        continue { |index, record| Step.exists?(record["step_id"]) }

        primary_key "id"
        whitelist "step_id", "release_platform_run_id", "scheduled_at", "status", "commit_id", "build_version",
          "sign_required", "approval_status"
        whitelist_timestamps
        anonymize("ci_link").using FieldStrategy::RandomUrl.new
        anonymize("build_number").using FieldStrategy::FormattedStringNumber.new
      end

      table "deployment_runs" do
        continue { |index, record| StepRun.exists?(record["step_run_id"]) }
        continue { |index, record| Deployment.exists?(record["deployment_id"]) }

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

      table "release_health_metrics" do
        continue { |index, record| DeploymentRun.exists?(record["deployment_run_id"]) }
        primary_key "id"
        whitelist "deployment_run_id", "sessions", "sessions_in_last_day", "sessions_with_errors", "daily_users",
          "daily_users_with_errors", "errors_count", "new_errors_count", "fetched_at", "total_sessions_in_last_day", "external_release_id"
        whitelist_timestamps
      end

      table "passports" do
        continue { |index, record| record["stampable_type"].constantize.exists?(record["stampable_id"]) }

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

    app.releases.each do |release|
      RefreshReportsJob.perform_now(release.id)
    end
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
end
