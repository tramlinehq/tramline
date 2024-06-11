# frozen_string_literal: true

class BackfillReleaseSlugs < ActiveRecord::Migration[7.0]
  def up
    Release.transaction do
      Release.all.each do |release|
        next if release.slug.present?
        release.update_column(:slug, release.human_slug.first)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
