# frozen_string_literal: true

class PopulatePlatformSpecificBugsnagConfig < ActiveRecord::Migration[7.0]
  def up
    return
    ActiveRecord::Base.transaction do
      AppConfig.all.each do |app_config|
        next if app_config.bugsnag_project_id.blank?

        app = app_config.app
        if app.ios? || app.cross_platform?
          app_config.update!(bugsnag_ios_config: {
            project_id: app_config.bugsnag_project_id,
            release_stage: "iOS-prod"
          })
        end

        if app.android? || app.cross_platform?
          app_config.update!(bugsnag_android_config: {
            project_id: app_config.bugsnag_project_id,
            release_stage: "prod"
          })
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
