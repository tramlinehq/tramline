# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_09_02_115549) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_configs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.json "code_repository"
    t.json "notification_channel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "bitrise_project_id"
    t.jsonb "firebase_ios_config"
    t.jsonb "firebase_android_config"
    t.jsonb "bugsnag_project_id"
    t.jsonb "bugsnag_ios_config"
    t.jsonb "bugsnag_android_config"
    t.index ["app_id"], name: "index_app_configs_on_app_id", unique: true
  end

  create_table "app_store_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key_id"
    t.string "p8_key"
    t.string "issuer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "app_variants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_config_id", null: false
    t.string "name", null: false
    t.string "bundle_identifier", null: false
    t.jsonb "firebase_ios_config"
    t.jsonb "firebase_android_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_config_id"], name: "index_app_variants_on_app_config_id"
    t.index ["bundle_identifier", "app_config_id"], name: "index_app_variants_on_bundle_identifier_and_app_config_id", unique: true
  end

  create_table "apps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "platform", null: false
    t.string "bundle_identifier", null: false
    t.bigint "build_number", null: false
    t.string "timezone", null: false
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.boolean "draft"
    t.index ["organization_id"], name: "index_apps_on_organization_id"
    t.index ["platform", "bundle_identifier", "organization_id"], name: "index_apps_on_platform_and_bundle_id_and_org_id", unique: true
  end

  create_table "bitbucket_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "oauth_access_token"
    t.string "oauth_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bitrise_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bugsnag_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "build_artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "step_run_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "generated_at", precision: nil
    t.datetime "uploaded_at", precision: nil
    t.uuid "build_id"
    t.index ["build_id"], name: "index_build_artifacts_on_build_id"
    t.index ["step_run_id"], name: "index_build_artifacts_on_step_run_id"
  end

  create_table "build_queues", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_id", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "applied_at"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_build_queues_on_is_active"
    t.index ["release_id"], name: "index_build_queues_on_release_id"
  end

  create_table "builds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "commit_id", null: false
    t.string "version_name"
    t.string "build_number"
    t.datetime "generated_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "workflow_run_id"
    t.string "external_id"
    t.string "external_name"
    t.bigint "size_in_bytes"
    t.integer "sequence_number", limit: 2, default: 0, null: false
    t.string "slack_file_id"
    t.index ["commit_id"], name: "index_builds_on_commit_id"
    t.index ["release_platform_run_id"], name: "index_builds_on_release_platform_run_id"
    t.index ["sequence_number"], name: "index_builds_on_sequence_number"
    t.index ["workflow_run_id"], name: "index_builds_on_workflow_run_id"
  end

  create_table "commit_listeners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_id"
    t.string "branch_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "train_id"
    t.index ["release_platform_id"], name: "index_commit_listeners_on_release_platform_id"
  end

  create_table "commits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "commit_hash", null: false
    t.uuid "release_platform_id"
    t.string "message"
    t.datetime "timestamp", null: false
    t.string "author_name", null: false
    t.string "author_email", null: false
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "release_platform_run_id"
    t.uuid "release_id"
    t.uuid "build_queue_id"
    t.boolean "backmerge_failure", default: false
    t.string "author_login"
    t.jsonb "parents"
    t.index ["build_queue_id"], name: "index_commits_on_build_queue_id"
    t.index ["commit_hash", "release_id"], name: "index_commits_on_commit_hash_and_release_id", unique: true
    t.index ["release_id", "timestamp"], name: "index_commits_on_release_id_and_timestamp"
    t.index ["release_platform_id"], name: "index_commits_on_release_platform_id"
    t.index ["release_platform_run_id"], name: "index_commits_on_release_platform_run_id"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "deployment_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_id", null: false
    t.uuid "step_run_id", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "initial_rollout_percentage", precision: 8, scale: 5
    t.string "failure_reason"
    t.index ["deployment_id", "step_run_id"], name: "index_deployment_runs_on_deployment_id_and_step_run_id", unique: true
    t.index ["step_run_id"], name: "index_deployment_runs_on_step_run_id"
  end

  create_table "deployments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "integration_id"
    t.uuid "step_id", null: false
    t.jsonb "build_artifact_channel"
    t.integer "deployment_number", limit: 2, default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "staged_rollout_config", default: [], array: true
    t.boolean "is_staged_rollout", default: false
    t.datetime "discarded_at"
    t.boolean "send_build_notes"
    t.string "notes", default: "no_notes", null: false
    t.index ["build_artifact_channel", "integration_id", "step_id"], name: "idx_kept_deployments_on_artifact_chan_and_integration_and_step", unique: true, where: "(discarded_at IS NULL)"
    t.index ["deployment_number", "step_id"], name: "index_deployments_on_deployment_number_and_step_id", unique: true
    t.index ["discarded_at"], name: "index_deployments_on_discarded_at"
    t.index ["integration_id"], name: "index_deployments_on_integration_id"
    t.index ["step_id"], name: "index_deployments_on_step_id"
  end

  create_table "email_authentications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_email_authentications_on_confirmation_token", unique: true
    t.index ["email"], name: "index_email_authentications_on_email", unique: true
    t.index ["reset_password_token"], name: "index_email_authentications_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_email_authentications_on_unlock_token", unique: true
  end

  create_table "external_apps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.datetime "fetched_at", precision: nil
    t.jsonb "channel_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform"
    t.string "default_locale"
    t.index ["app_id"], name: "index_external_apps_on_app_id"
    t.index ["fetched_at"], name: "index_external_apps_on_fetched_at"
  end

  create_table "external_builds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "step_run_id", null: false
    t.jsonb "metadata", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["step_run_id"], name: "index_external_builds_on_step_run_id", unique: true
  end

  create_table "external_releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_run_id", null: false
    t.string "name"
    t.string "build_number"
    t.string "status"
    t.datetime "added_at", precision: nil
    t.integer "size_in_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.datetime "reviewed_at"
    t.datetime "released_at"
    t.string "external_link"
    t.index ["deployment_run_id"], name: "index_external_releases_on_deployment_run_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "github_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "installation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "gitlab_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "oauth_access_token"
    t.string "original_oauth_access_token"
    t.string "oauth_refresh_token"
    t.string "original_oauth_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_firebase_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "json_key"
    t.string "project_number"
    t.string "app_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_play_store_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "json_key"
    t.string "original_json_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.string "category", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "providable_id"
    t.string "providable_type"
    t.jsonb "metadata"
    t.datetime "discarded_at"
    t.index ["app_id", "category", "providable_type", "status"], name: "unique_connected_integration_category", unique: true, where: "((status)::text = 'connected'::text)"
    t.index ["app_id"], name: "index_integrations_on_app_id"
    t.index ["providable_type", "providable_id"], name: "index_integrations_on_providable_type_and_providable_id", unique: true
  end

  create_table "invites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "sender_id", null: false
    t.uuid "recipient_id"
    t.string "email"
    t.string "token"
    t.string "role"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_invites_on_organization_id"
    t.index ["recipient_id"], name: "index_invites_on_recipient_id"
    t.index ["sender_id"], name: "index_invites_on_sender_id"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "organization_id"
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "team_id"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["role"], name: "index_memberships_on_role"
    t.index ["user_id", "organization_id", "role"], name: "index_memberships_on_user_id_and_organization_id_and_role", unique: true
  end

  create_table "notification_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.string "kind", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "notification_channels"
    t.jsonb "user_groups"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["train_id", "kind"], name: "index_notification_settings_on_train_id_and_kind", unique: true
    t.index ["train_id"], name: "index_notification_settings_on_train_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", null: false
    t.string "name", null: false
    t.string "slug"
    t.string "created_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "subscribed", default: false
    t.string "api_key"
    t.boolean "sso", default: false
    t.string "sso_tenant_id"
    t.string "sso_tenant_name"
    t.string "sso_domains", default: [], array: true
    t.string "sso_protocol"
    t.string "sso_configuration_link"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["status"], name: "index_organizations_on_status"
  end

  create_table "passports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "stampable_type", null: false
    t.uuid "stampable_id", null: false
    t.string "reason"
    t.string "kind"
    t.string "message"
    t.json "metadata"
    t.uuid "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "event_timestamp", null: false
    t.jsonb "author_metadata"
    t.boolean "automatic", default: true
    t.index ["author_id"], name: "index_passports_on_author_id"
    t.index ["kind"], name: "index_passports_on_kind"
    t.index ["reason"], name: "index_passports_on_reason"
    t.index ["stampable_type", "stampable_id"], name: "index_passports_on_stampable"
  end

  create_table "pre_prod_releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "commit_id", null: false
    t.uuid "previous_id"
    t.uuid "parent_internal_release_id"
    t.string "type", null: false
    t.string "status", default: "created", null: false
    t.jsonb "config", default: {}, null: false
    t.text "tester_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_pre_prod_releases_on_commit_id"
    t.index ["parent_internal_release_id"], name: "index_pre_prod_releases_on_parent_internal_release_id"
    t.index ["previous_id"], name: "index_pre_prod_releases_on_previous_id"
    t.index ["release_platform_run_id"], name: "index_pre_prod_releases_on_release_platform_run_id"
  end

  create_table "production_releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "build_id", null: false
    t.uuid "previous_id"
    t.jsonb "config", default: {}, null: false
    t.string "status", default: "inflight", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["build_id"], name: "index_production_releases_on_build_id"
    t.index ["previous_id"], name: "index_production_releases_on_previous_id"
    t.index ["release_platform_run_id", "status"], name: "index_unique_active_production_release", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["release_platform_run_id", "status"], name: "index_unique_finished_production_release", unique: true, where: "((status)::text = 'finished'::text)"
    t.index ["release_platform_run_id", "status"], name: "index_unique_inflight_production_release", unique: true, where: "((status)::text = 'inflight'::text)"
    t.index ["release_platform_run_id"], name: "index_production_releases_on_release_platform_run_id"
  end

  create_table "pull_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id"
    t.bigint "number", null: false
    t.string "source_id", null: false
    t.string "url"
    t.string "title", null: false
    t.text "body"
    t.string "state", null: false
    t.string "phase", null: false
    t.string "source", null: false
    t.string "head_ref", null: false
    t.string "base_ref", null: false
    t.datetime "opened_at", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "release_id"
    t.uuid "commit_id"
    t.jsonb "labels"
    t.index ["commit_id"], name: "index_pull_requests_on_commit_id"
    t.index ["number"], name: "index_pull_requests_on_number"
    t.index ["phase"], name: "index_pull_requests_on_phase"
    t.index ["release_id", "head_ref"], name: "index_pull_requests_on_release_id_and_head_ref"
    t.index ["release_id", "phase", "number"], name: "idx_prs_on_release_id_and_phase_and_number", unique: true
    t.index ["source"], name: "index_pull_requests_on_source"
    t.index ["source_id"], name: "index_pull_requests_on_source_id"
    t.index ["state"], name: "index_pull_requests_on_state"
  end

  create_table "release_changelogs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_id", null: false
    t.string "from_ref", null: false
    t.jsonb "commits"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["release_id"], name: "index_release_changelogs_on_release_id"
  end

  create_table "release_health_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_run_id", null: false
    t.uuid "release_health_rule_id", null: false
    t.uuid "release_health_metric_id", null: false
    t.string "health_status", null: false
    t.datetime "event_timestamp", null: false
    t.boolean "notification_triggered", default: false
    t.boolean "action_triggered", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deployment_run_id", "release_health_rule_id", "release_health_metric_id"], name: "idx_events_on_deployment_and_rule_and_metric", unique: true
    t.index ["deployment_run_id"], name: "index_release_health_events_on_deployment_run_id"
    t.index ["event_timestamp"], name: "index_release_health_events_on_event_timestamp"
    t.index ["release_health_metric_id"], name: "index_release_health_events_on_release_health_metric_id"
    t.index ["release_health_rule_id"], name: "index_release_health_events_on_release_health_rule_id"
  end

  create_table "release_health_metrics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_run_id"
    t.bigint "sessions"
    t.bigint "sessions_in_last_day"
    t.bigint "sessions_with_errors"
    t.bigint "daily_users"
    t.bigint "daily_users_with_errors"
    t.bigint "errors_count"
    t.bigint "new_errors_count"
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "total_sessions_in_last_day"
    t.string "external_release_id"
    t.uuid "production_release_id"
    t.index ["deployment_run_id"], name: "index_release_health_metrics_on_deployment_run_id"
    t.index ["fetched_at"], name: "index_release_health_metrics_on_fetched_at"
    t.index ["production_release_id"], name: "index_release_health_metrics_on_production_release_id"
  end

  create_table "release_health_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "is_halting", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.uuid "release_platform_id", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_release_health_rules_on_discarded_at"
    t.index ["release_platform_id"], name: "index_release_health_rules_on_release_platform_id"
  end

  create_table "release_index_components", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_index_id", null: false
    t.numrange "tolerable_range", null: false
    t.string "tolerable_unit", null: false
    t.string "name", null: false
    t.decimal "weight", precision: 4, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "release_index_id"], name: "index_release_index_components_on_name_and_release_index_id", unique: true
    t.index ["release_index_id"], name: "index_release_index_components_on_release_index_id"
  end

  create_table "release_indices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.numrange "tolerable_range", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["train_id"], name: "index_release_indices_on_train_id"
  end

  create_table "release_metadata", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id"
    t.string "locale", null: false
    t.text "release_notes"
    t.text "promo_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "release_id"
    t.text "description"
    t.string "keywords", default: [], array: true
    t.boolean "default_locale", default: false
    t.index ["release_platform_run_id", "locale"], name: "index_release_metadata_on_release_platform_run_id_and_locale", unique: true
    t.index ["release_platform_run_id"], name: "index_release_metadata_on_release_platform_run_id"
  end

  create_table "release_platform_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_id", null: false
    t.string "code_name", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "commit_sha"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "branch_name"
    t.string "release_version"
    t.datetime "completed_at"
    t.datetime "stopped_at"
    t.string "original_release_version"
    t.uuid "release_id"
    t.string "tag_name"
    t.boolean "in_store_resubmission", default: false
    t.uuid "last_commit_id"
    t.jsonb "config"
    t.boolean "play_store_blocked", default: false
    t.index ["last_commit_id"], name: "index_release_platform_runs_on_last_commit_id"
    t.index ["release_platform_id"], name: "index_release_platform_runs_on_release_platform_id"
  end

  create_table "release_platforms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "status"
    t.string "version_seeded_with"
    t.string "version_current"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "working_branch"
    t.string "branching_strategy"
    t.string "release_branch"
    t.string "release_backmerge_branch"
    t.string "vcs_webhook_id"
    t.uuid "train_id"
    t.string "platform"
    t.jsonb "config"
    t.index ["app_id"], name: "index_release_platforms_on_app_id"
  end

  create_table "releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.string "branch_name", null: false
    t.string "status", null: false
    t.string "original_release_version"
    t.string "release_version"
    t.datetime "scheduled_at", precision: nil
    t.datetime "completed_at", precision: nil
    t.datetime "stopped_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_automatic", default: false
    t.string "tag_name"
    t.string "release_type", null: false
    t.boolean "new_hotfix_branch", default: false
    t.uuid "hotfixed_from"
    t.jsonb "internal_notes", default: {}
    t.uuid "release_pilot_id"
    t.string "slug"
    t.boolean "is_v2", default: false
    t.index ["slug"], name: "index_releases_on_slug", unique: true
    t.index ["train_id"], name: "index_releases_on_train_id"
  end

  create_table "rule_expressions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_health_rule_id", null: false
    t.string "type", null: false
    t.string "metric", null: false
    t.string "comparator", null: false
    t.float "threshold_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric"], name: "index_rule_expressions_on_metric"
    t.index ["release_health_rule_id", "metric"], name: "unique_index_on_release_health_rule_id_and_metric_for_triggers", unique: true, where: "((type)::text = 'TriggerRuleExpression'::text)"
    t.index ["release_health_rule_id"], name: "index_rule_expressions_on_release_health_rule_id"
  end

  create_table "scheduled_releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.boolean "is_success", default: false
    t.string "failure_reason"
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "release_id"
    t.index ["train_id"], name: "index_scheduled_releases_on_train_id"
  end

  create_table "slack_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "oauth_access_token"
    t.string "original_oauth_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sso_authentications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "login_id"
    t.string "email", default: "", null: false
    t.datetime "logout_time"
    t.datetime "sso_created_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_sso_authentications_on_email", unique: true
    t.index ["login_id"], name: "index_sso_authentications_on_login_id", unique: true, where: "(login_id IS NOT NULL)"
  end

  create_table "staged_rollouts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_run_id", null: false
    t.decimal "config", precision: 8, scale: 5, default: [], array: true
    t.string "status"
    t.integer "current_stage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deployment_run_id"], name: "index_staged_rollouts_on_deployment_run_id"
  end

  create_table "step_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "step_id", null: false
    t.uuid "release_platform_run_id", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "commit_id", null: false
    t.string "build_version", null: false
    t.string "ci_ref"
    t.string "ci_link"
    t.string "build_number"
    t.boolean "sign_required", default: true
    t.string "approval_status", default: "pending", null: false
    t.text "build_notes_raw", default: [], array: true
    t.string "slack_file_id"
    t.index ["build_number", "build_version"], name: "index_step_runs_on_build_number_and_build_version"
    t.index ["commit_id"], name: "index_step_runs_on_commit_id"
    t.index ["release_platform_run_id"], name: "index_step_runs_on_release_platform_run_id"
    t.index ["step_id", "commit_id"], name: "index_step_runs_on_step_id_and_commit_id", unique: true
    t.index ["step_id"], name: "index_step_runs_on_step_id"
  end

  create_table "steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_id", null: false
    t.string "name", null: false
    t.string "description", null: false
    t.string "status", null: false
    t.integer "step_number", limit: 2, default: 0, null: false
    t.jsonb "ci_cd_channel", null: false
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "release_suffix"
    t.string "kind"
    t.boolean "auto_deploy", default: true
    t.string "build_artifact_name_pattern"
    t.uuid "app_variant_id"
    t.uuid "integration_id"
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_steps_on_discarded_at"
    t.index ["integration_id"], name: "index_steps_on_integration_id"
    t.index ["release_platform_id", "ci_cd_channel"], name: "index_kept_steps_on_release_platform_id_and_ci_cd_channel", unique: true, where: "(discarded_at IS NULL)"
    t.index ["release_platform_id"], name: "index_steps_on_release_platform_id"
    t.index ["step_number", "release_platform_id"], name: "index_steps_on_step_number_and_release_platform_id", unique: true
  end

  create_table "store_rollouts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "store_submission_id"
    t.string "type", null: false
    t.string "status", null: false
    t.datetime "completed_at"
    t.integer "current_stage", limit: 2
    t.decimal "config", precision: 8, scale: 5, default: [], null: false, array: true
    t.boolean "is_staged_rollout", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["release_platform_run_id"], name: "index_store_rollouts_on_release_platform_run_id"
    t.index ["store_submission_id"], name: "index_store_rollouts_on_store_submission_id"
  end

  create_table "store_submissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "build_id", null: false
    t.string "status", null: false
    t.string "name"
    t.string "type", null: false
    t.string "failure_reason"
    t.datetime "prepared_at", precision: nil
    t.datetime "submitted_at", precision: nil
    t.datetime "rejected_at", precision: nil
    t.datetime "approved_at", precision: nil
    t.string "store_link"
    t.string "store_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "store_release"
    t.string "parent_release_type"
    t.uuid "parent_release_id"
    t.jsonb "config"
    t.integer "sequence_number", limit: 2, default: 0, null: false
    t.index ["build_id"], name: "index_store_submissions_on_build_id"
    t.index ["parent_release_type", "parent_release_id"], name: "index_store_submissions_on_parent_release"
    t.index ["release_platform_run_id"], name: "index_store_submissions_on_release_platform_run_id"
    t.index ["sequence_number"], name: "index_store_submissions_on_sequence_number"
  end

  create_table "teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_teams_on_organization_id"
  end

  create_table "trains", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "status", null: false
    t.string "branching_strategy", null: false
    t.string "release_branch"
    t.string "release_backmerge_branch"
    t.string "working_branch"
    t.string "vcs_webhook_id"
    t.string "slug"
    t.string "version_seeded_with"
    t.string "version_current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "kickoff_at"
    t.interval "repeat_duration"
    t.jsonb "notification_channel"
    t.boolean "build_queue_enabled", default: false
    t.interval "build_queue_wait_time"
    t.integer "build_queue_size", limit: 2
    t.string "backmerge_strategy", default: "on_finalize", null: false
    t.boolean "manual_release", default: false
    t.boolean "tag_platform_releases", default: false
    t.boolean "tag_all_store_releases", default: false
    t.boolean "compact_build_notes", default: false
    t.boolean "tag_releases", default: true
    t.string "tag_suffix"
    t.string "versioning_strategy", default: "semver"
    t.boolean "stop_automatic_releases_on_failure", default: false, null: false
    t.boolean "patch_version_bump_only", default: false, null: false
    t.index ["app_id"], name: "index_trains_on_app_id"
  end

  create_table "user_authentications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "authenticatable_type", null: false
    t.uuid "authenticatable_id", null: false
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authenticatable_type", "authenticatable_id"], name: "index_user_authentications_on_authenticatable"
    t.index ["user_id"], name: "index_user_authentications_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "full_name", null: false
    t.string "preferred_name"
    t.string "slug"
    t.boolean "admin", default: false
    t.string "email", default: ""
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "github_login"
    t.string "github_id"
    t.string "unique_authn_id", default: "", null: false
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type"
    t.string "{:null=>false}"
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "workflow_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "release_platform_run_id", null: false
    t.uuid "commit_id", null: false
    t.uuid "pre_prod_release_id", null: false
    t.string "status", null: false
    t.string "kind", default: "release_candidate", null: false
    t.jsonb "workflow_config"
    t.string "external_id"
    t.string "external_url"
    t.string "external_number"
    t.string "artifacts_url"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_workflow_runs_on_commit_id"
    t.index ["pre_prod_release_id"], name: "index_workflow_runs_on_pre_prod_release_id"
    t.index ["release_platform_run_id"], name: "index_workflow_runs_on_release_platform_run_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "app_configs", "apps"
  add_foreign_key "app_variants", "app_configs"
  add_foreign_key "apps", "organizations"
  add_foreign_key "build_artifacts", "step_runs"
  add_foreign_key "build_queues", "releases"
  add_foreign_key "builds", "commits"
  add_foreign_key "builds", "release_platform_runs"
  add_foreign_key "builds", "workflow_runs"
  add_foreign_key "commit_listeners", "release_platforms"
  add_foreign_key "commits", "build_queues"
  add_foreign_key "commits", "release_platform_runs"
  add_foreign_key "commits", "release_platforms"
  add_foreign_key "deployment_runs", "deployments"
  add_foreign_key "deployment_runs", "step_runs"
  add_foreign_key "deployments", "steps"
  add_foreign_key "external_apps", "apps"
  add_foreign_key "external_builds", "step_runs"
  add_foreign_key "external_releases", "deployment_runs"
  add_foreign_key "integrations", "apps"
  add_foreign_key "invites", "organizations"
  add_foreign_key "invites", "users", column: "recipient_id"
  add_foreign_key "invites", "users", column: "sender_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "notification_settings", "trains"
  add_foreign_key "pre_prod_releases", "commits"
  add_foreign_key "pre_prod_releases", "pre_prod_releases", column: "parent_internal_release_id"
  add_foreign_key "pre_prod_releases", "pre_prod_releases", column: "previous_id"
  add_foreign_key "pre_prod_releases", "release_platform_runs"
  add_foreign_key "production_releases", "builds"
  add_foreign_key "production_releases", "production_releases", column: "previous_id"
  add_foreign_key "production_releases", "release_platform_runs"
  add_foreign_key "pull_requests", "release_platform_runs"
  add_foreign_key "release_changelogs", "releases"
  add_foreign_key "release_health_events", "deployment_runs"
  add_foreign_key "release_health_events", "release_health_metrics"
  add_foreign_key "release_health_events", "release_health_rules"
  add_foreign_key "release_health_metrics", "deployment_runs"
  add_foreign_key "release_health_metrics", "production_releases"
  add_foreign_key "release_health_rules", "release_platforms"
  add_foreign_key "release_index_components", "release_indices"
  add_foreign_key "release_indices", "trains"
  add_foreign_key "release_metadata", "release_platform_runs"
  add_foreign_key "release_platform_runs", "commits", column: "last_commit_id"
  add_foreign_key "release_platform_runs", "release_platforms"
  add_foreign_key "release_platforms", "apps"
  add_foreign_key "releases", "trains"
  add_foreign_key "rule_expressions", "release_health_rules"
  add_foreign_key "scheduled_releases", "trains"
  add_foreign_key "staged_rollouts", "deployment_runs"
  add_foreign_key "step_runs", "commits"
  add_foreign_key "step_runs", "release_platform_runs"
  add_foreign_key "step_runs", "steps"
  add_foreign_key "steps", "release_platforms"
  add_foreign_key "store_rollouts", "release_platform_runs"
  add_foreign_key "store_rollouts", "store_submissions"
  add_foreign_key "store_submissions", "builds"
  add_foreign_key "store_submissions", "release_platform_runs"
  add_foreign_key "teams", "organizations"
  add_foreign_key "trains", "apps"
  add_foreign_key "user_authentications", "users"
  add_foreign_key "workflow_runs", "commits"
  add_foreign_key "workflow_runs", "pre_prod_releases"
  add_foreign_key "workflow_runs", "release_platform_runs"
end
