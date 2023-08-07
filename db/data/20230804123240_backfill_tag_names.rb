# frozen_string_literal: true

class BackfillTagNames < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Release.where(tag_name: nil).each do |release|
        release.update!(tag_name: release.send(:base_tag_name))
      end

      ReleasePlatformRun.where(tag_name: nil).each do |platform_run|
        platform_run.update!(tag_name: platform_run.send(:base_tag_name)) if platform_run.app.cross_platform?
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
