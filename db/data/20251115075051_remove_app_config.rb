# frozen_string_literal: true

class RemoveAppConfig < ActiveRecord::Migration[7.2]
  def up
    return
    ActiveRecord::Base.transaction do
      # Migrate app_config data to integrations and app_variants
      migrate_app_config_data

      # Update app_variant app_id references
      migrate_app_variant_references

      # Migrate app_variant firebase configs to integrations
      migrate_app_variant_firebase_configs
    end

    unready_app_slugs = App.find_each.reject { |a| a.ready? }.map(&:slug)

    say "These apps are unready -- #{unready_app_slugs}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_app_config_data
    say "Migrating AppConfig data to integrations..."

    AppConfig.find_each do |app_config|
      app = App.find(app_config.app_id)

      # Migrate configs to their respective integrations
      migrate_firebase_configs(app, app_config)
      migrate_bugsnag_configs(app, app_config)
      migrate_vcs_configs(app, app_config)
      migrate_ci_cd_configs(app, app_config)
      migrate_jira_configs(app, app_config)
      migrate_linear_configs(app, app_config)

      say "Migrated AppConfig #{app_config.id} for App #{app.name}"
    end
  end

  def migrate_firebase_configs(app, app_config)
    firebase_integration = app.integrations.firebase_build_channel_provider

    if firebase_integration.is_a?(GoogleFirebaseIntegration)
      updates = {}

      if app_config.firebase_android_config.present?
        updates[:android_config] = app_config.firebase_android_config
      end

      if app_config.firebase_ios_config.present?
        updates[:ios_config] = app_config.firebase_ios_config
      end

      if updates.any?
        firebase_integration.update!(updates)
        say "  ↳ Migrated Firebase configs to integration #{firebase_integration.id}"
      end
    end
  end

  def migrate_bugsnag_configs(app, app_config)
    bugsnag_integration = app.integrations.monitoring_provider

    if bugsnag_integration.is_a?(BugsnagIntegration)
      updates = {}

      if app_config.bugsnag_android_config.present?
        updates[:android_config] = app_config.bugsnag_android_config
      end

      if app_config.bugsnag_ios_config.present?
        updates[:ios_config] = app_config.bugsnag_ios_config
      end

      if updates.any?
        bugsnag_integration.update!(updates)
        say "  ↳ Migrated Bugsnag configs to integration #{bugsnag_integration.id}"
      end
    end
  end

  def migrate_vcs_configs(app, app_config)
    vcs_provider = app.integrations.vcs_provider

    if vcs_provider.present?
      updates = {}

      if app_config.code_repository.present?
        updates[:repository_config] = app_config.code_repository
      end

      if app_config.bitbucket_workspace.present? && vcs_provider.is_a?(BitbucketIntegration)
        updates[:workspace] = app_config.bitbucket_workspace
      end

      if updates.any?
        vcs_provider.update!(updates)
        say "  ↳ Migrated VCS configs to integration #{vcs_provider.id}"
      end
    end
  end

  def migrate_ci_cd_configs(app, app_config)
    ci_cd_provider = app.integrations.ci_cd_provider

    if ci_cd_provider.present?
      updates = {}

      if ci_cd_provider.is_a?(GithubIntegration) || ci_cd_provider.is_a?(GitlabIntegration) || ci_cd_provider.is_a?(BitbucketIntegration)
        if app_config.code_repository.present?
          updates[:repository_config] = app_config.code_repository
        end
      end

      if app_config.bitrise_project_id.present? && ci_cd_provider.is_a?(BitriseIntegration)
          updates[:project_config] = app_config.bitrise_project_id
      end

      if app_config.bitbucket_workspace.present? && ci_cd_provider.is_a?(BitbucketIntegration)
        updates[:workspace] = app_config.bitbucket_workspace
      end

      if updates.any?
        ci_cd_provider.update!(updates)
        say "  ↳ Migrated CI/CD configs to integration #{ci_cd_provider.id}"
      end
    end
  end

  def migrate_jira_configs(app, app_config)
    jira_integration = app.integrations.project_management.find(&:jira_integration?)&.providable

    if jira_integration.is_a?(JiraIntegration) && app_config.jira_config.present?
      jira_integration.update!(project_config: app_config.jira_config)
      say "  ↳ Migrated Jira config to integration #{jira_integration.id}"
    end
  end

  def migrate_linear_configs(app, app_config)
    linear_integration = app.integrations.project_management.find(&:linear_integration?)&.providable

    if linear_integration.is_a?(LinearIntegration) && app_config.linear_config.present?
      linear_integration.update!(project_config: app_config.linear_config)
      say "  ↳ Migrated Linear config to integration #{linear_integration.id}"
    end
  end

  def migrate_app_variant_references
    say "Updating AppVariant app_id references..."

    AppVariant.where(app_id: nil).find_each do |variant|
      if variant.app_config_id.present?
        app_config = AppConfig.find(variant.app_config_id)
        variant.update!(app_id: app_config.app_id)
        say "  ↳ Updated AppVariant #{variant.name} app_id to #{app_config.app_id}"
      else
        say "  ↳ WARNING: AppVariant #{variant.name} has no app_config_id, skipping"
      end
    end
  end

  def migrate_app_variant_firebase_configs
    say "Migrating AppVariant Firebase configs to integrations..."

    AppVariant.find_each do |variant|
      # Find Firebase integration for this variant
      firebase_integration = variant.integrations.firebase_build_channel_provider

      if firebase_integration.is_a?(GoogleFirebaseIntegration)
        updates = {}

        if variant.firebase_android_config.present?
          updates[:android_config] = variant.firebase_android_config
        end

        if variant.firebase_ios_config.present?
          updates[:ios_config] = variant.firebase_ios_config
        end

        if updates.any?
          firebase_integration.update!(updates)
          say "  ↳ Migrated Firebase configs from AppVariant #{variant.name} to integration #{firebase_integration.id}"
        end
      else
        # Check if variant has firebase configs but no integration
        if variant.firebase_android_config.present? || variant.firebase_ios_config.present?
          say "  ↳ WARNING: AppVariant #{variant.name} has Firebase configs but no Firebase integration"
        end
      end
    end
  end
end
