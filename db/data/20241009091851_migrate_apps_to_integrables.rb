# frozen_string_literal: true

class MigrateAppsToIntegrables < ActiveRecord::Migration[7.2]
  def up
    Integration.where.not(app_id: nil).find_each do |i|
      i.integrable_id = i.attributes["app_id"]
      i.integrable_type = "App"
      i.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
