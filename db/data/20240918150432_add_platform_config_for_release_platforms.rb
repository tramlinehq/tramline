# frozen_string_literal: true

class AddPlatformConfigForReleasePlatforms < ActiveRecord::Migration[7.2]
  def up
    return
    ActiveRecord::Base.transaction do
      ReleasePlatform.all.each do |release_platform|
        next if release_platform.platform_config.present?
        next unless release_platform.config.present?

        config = Config::ReleasePlatform.from_json(release_platform.config)
        config.release_platform = release_platform
        config.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
