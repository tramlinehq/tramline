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

ActiveRecord::Schema[7.0].define(version: 2023_05_26_110225) do
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
    t.jsonb "project_id"
    t.index ["app_id"], name: "index_app_configs_on_app_id", unique: true
  end

  create_table "app_store_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key_id"
    t.string "p8_key"
    t.string "issuer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["organization_id"], name: "index_apps_on_organization_id"
    t.index ["platform", "bundle_identifier", "organization_id"], name: "index_apps_on_platform_and_bundle_id_and_org_id", unique: true
  end

  create_table "bitrise_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "build_artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_step_runs_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "generated_at", precision: nil
    t.datetime "uploaded_at", precision: nil
    t.index ["train_step_runs_id"], name: "index_build_artifacts_on_train_step_runs_id"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "deployment_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "deployment_id", null: false
    t.uuid "train_step_run_id", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "initial_rollout_percentage", precision: 8, scale: 5
    t.string "failure_reason"
    t.index ["deployment_id", "train_step_run_id"], name: "index_deployment_runs_on_deployment_id_and_train_step_run_id", unique: true
    t.index ["train_step_run_id"], name: "index_deployment_runs_on_train_step_run_id"
  end

  create_table "deployments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "integration_id"
    t.uuid "train_step_id", null: false
    t.jsonb "build_artifact_channel"
    t.integer "deployment_number", limit: 2, default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "staged_rollout_config", default: [], array: true
    t.boolean "is_staged_rollout", default: false
    t.index ["build_artifact_channel", "integration_id", "train_step_id"], name: "idx_deployments_on_build_artifact_chan_and_integration_and_step", unique: true
    t.index ["deployment_number", "train_step_id"], name: "index_deployments_on_deployment_number_and_train_step_id", unique: true
    t.index ["integration_id"], name: "index_deployments_on_integration_id"
    t.index ["train_step_id"], name: "index_deployments_on_train_step_id"
  end

  create_table "external_apps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.datetime "fetched_at", precision: nil
    t.jsonb "channel_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_external_apps_on_app_id"
    t.index ["fetched_at"], name: "index_external_apps_on_fetched_at"
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
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "github_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "installation_id"
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
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["role"], name: "index_memberships_on_role"
    t.index ["user_id", "organization_id", "role"], name: "index_memberships_on_user_id_and_organization_id_and_role", unique: true
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", null: false
    t.string "name", null: false
    t.string "slug"
    t.string "created_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "event_timestamp", null: false
    t.index ["kind"], name: "index_passports_on_kind"
    t.index ["reason"], name: "index_passports_on_reason"
    t.index ["stampable_type", "stampable_id"], name: "index_passports_on_stampable"
  end

  create_table "release_metadata", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_run_id", null: false
    t.string "locale", null: false
    t.text "release_notes"
    t.text "promo_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["train_run_id", "locale"], name: "index_release_metadata_on_train_run_id_and_locale", unique: true
    t.index ["train_run_id"], name: "index_release_metadata_on_train_run_id"
  end

  create_table "releases_commit_listeners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.string "branch_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["train_id"], name: "index_releases_commit_listeners_on_train_id"
  end

  create_table "releases_commits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "commit_hash", null: false
    t.uuid "train_id", null: false
    t.string "message"
    t.datetime "timestamp", null: false
    t.string "author_name", null: false
    t.string "author_email", null: false
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "train_run_id", null: false
    t.index ["commit_hash", "train_run_id"], name: "index_releases_commits_on_commit_hash_and_train_run_id", unique: true
    t.index ["train_id"], name: "index_releases_commits_on_train_id"
    t.index ["train_run_id"], name: "index_releases_commits_on_train_run_id"
  end

  create_table "releases_pull_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_run_id", null: false
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
    t.index ["number"], name: "index_releases_pull_requests_on_number"
    t.index ["phase"], name: "index_releases_pull_requests_on_phase"
    t.index ["source"], name: "index_releases_pull_requests_on_source"
    t.index ["source_id"], name: "index_releases_pull_requests_on_source_id"
    t.index ["state"], name: "index_releases_pull_requests_on_state"
    t.index ["train_run_id", "head_ref", "base_ref"], name: "idx_prs_on_train_run_id_and_head_ref_and_base_ref", unique: true
  end

  create_table "sign_off_group_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "sign_off_group_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sign_off_group_id"], name: "index_sign_off_group_memberships_on_sign_off_group_id"
    t.index ["user_id"], name: "index_sign_off_group_memberships_on_user_id"
  end

  create_table "sign_off_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "app_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_sign_off_groups_on_app_id"
  end

  create_table "sign_offs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "sign_off_group_id", null: false
    t.uuid "train_step_id", null: false
    t.uuid "user_id", null: false
    t.boolean "signed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "releases_commit_id", null: false
    t.index ["releases_commit_id", "train_step_id", "sign_off_group_id"], name: "idx_sign_offs_on_commit_step_and_group_id", unique: true
    t.index ["sign_off_group_id"], name: "index_sign_offs_on_sign_off_group_id"
    t.index ["train_step_id"], name: "index_sign_offs_on_train_step_id"
    t.index ["user_id"], name: "index_sign_offs_on_user_id"
  end

  create_table "slack_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "oauth_access_token"
    t.string "original_oauth_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "train_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.string "code_name", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "commit_sha"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "branch_name", null: false
    t.string "release_version", null: false
    t.datetime "completed_at"
    t.datetime "stopped_at"
    t.string "original_release_version"
    t.index ["train_id"], name: "index_train_runs_on_train_id"
  end

  create_table "train_sign_off_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
    t.uuid "sign_off_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sign_off_group_id"], name: "index_train_sign_off_groups_on_sign_off_group_id"
    t.index ["train_id"], name: "index_train_sign_off_groups_on_train_id"
  end

  create_table "train_step_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_step_id", null: false
    t.uuid "train_run_id", null: false
    t.datetime "scheduled_at", precision: nil, null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "releases_commit_id", null: false
    t.string "build_version", null: false
    t.string "ci_ref"
    t.string "ci_link"
    t.string "build_number"
    t.boolean "sign_required", default: true
    t.string "approval_status", default: "pending", null: false
    t.index ["releases_commit_id"], name: "index_train_step_runs_on_releases_commit_id"
    t.index ["train_run_id"], name: "index_train_step_runs_on_train_run_id"
    t.index ["train_step_id"], name: "index_train_step_runs_on_train_step_id"
  end

  create_table "train_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "train_id", null: false
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
    t.index ["ci_cd_channel", "train_id"], name: "index_train_steps_on_ci_cd_channel_and_train_id", unique: true
    t.index ["step_number", "train_id"], name: "index_train_steps_on_step_number_and_train_id", unique: true
    t.index ["train_id"], name: "index_train_steps_on_train_id"
  end

  create_table "trains", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_id", null: false
    t.string "name", null: false
    t.string "description", null: false
    t.string "status", null: false
    t.string "version_seeded_with", null: false
    t.string "version_current"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "working_branch"
    t.string "branching_strategy"
    t.string "release_branch"
    t.string "release_backmerge_branch"
    t.string "vcs_webhook_id"
    t.index ["app_id"], name: "index_trains_on_app_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "full_name", null: false
    t.string "preferred_name"
    t.string "slug"
    t.boolean "admin", default: false
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "app_configs", "apps"
  add_foreign_key "apps", "organizations"
  add_foreign_key "build_artifacts", "train_step_runs", column: "train_step_runs_id"
  add_foreign_key "deployment_runs", "deployments"
  add_foreign_key "deployment_runs", "train_step_runs"
  add_foreign_key "deployments", "train_steps"
  add_foreign_key "external_apps", "apps"
  add_foreign_key "external_releases", "deployment_runs"
  add_foreign_key "integrations", "apps"
  add_foreign_key "invites", "organizations"
  add_foreign_key "invites", "users", column: "recipient_id"
  add_foreign_key "invites", "users", column: "sender_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "release_metadata", "train_runs"
  add_foreign_key "releases_commit_listeners", "trains"
  add_foreign_key "releases_commits", "train_runs"
  add_foreign_key "releases_commits", "trains"
  add_foreign_key "releases_pull_requests", "train_runs"
  add_foreign_key "sign_off_group_memberships", "sign_off_groups"
  add_foreign_key "sign_off_group_memberships", "users"
  add_foreign_key "sign_off_groups", "apps"
  add_foreign_key "sign_offs", "releases_commits"
  add_foreign_key "sign_offs", "sign_off_groups"
  add_foreign_key "sign_offs", "train_steps"
  add_foreign_key "sign_offs", "users"
  add_foreign_key "staged_rollouts", "deployment_runs"
  add_foreign_key "train_runs", "trains"
  add_foreign_key "train_sign_off_groups", "sign_off_groups"
  add_foreign_key "train_sign_off_groups", "trains"
  add_foreign_key "train_step_runs", "releases_commits"
  add_foreign_key "train_step_runs", "train_runs"
  add_foreign_key "train_step_runs", "train_steps"
  add_foreign_key "train_steps", "trains"
  add_foreign_key "trains", "apps"
end
