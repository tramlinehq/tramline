# frozen_string_literal: true

class AddIntegrablesToAllRuntimeModelConfigs < ActiveRecord::Migration[7.2]
  def up
    PreProdRelease.find_each do |release|
      app = release.release_platform_run.app
      config = release.config
      config["submissions"].each do |submission|
        submission["integrable_id"] = app.id
        submission["integrable_type"] = "App"
      end
      release.update! config: config
    end

    ProductionRelease.find_each do |release|
      app = release.release_platform_run.app
      config = release.config
      config["submissions"].each do |submission|
        submission["integrable_id"] = app.id
        submission["integrable_type"] = "App"
      end
      release.update! config: config
    end

    ReleasePlatformRun.find_each do |run|
      config = run.config
      next unless config.present?

      app = run.app
      if config.dig("internal_release", "submissions").present?
        config["internal_release"]["submissions"].each do |submission|
          submission["integrable_id"] = app.id
          submission["integrable_type"] = "App"
        end
      end

      if config.dig("beta_release", "submissions").present?
        config["beta_release"]["submissions"].each do |submission|
          submission["integrable_id"] = app.id
          submission["integrable_type"] = "App"
        end
      end

      if config.dig("production_release", "submissions").present?
        config["production_release"]["submissions"].each do |submission|
          submission["integrable_id"] = app.id
          submission["integrable_type"] = "App"
        end
      end

      run.update! config: config
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
