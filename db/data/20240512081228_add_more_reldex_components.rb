# frozen_string_literal: true

class AddMoreReldexComponents < ActiveRecord::Migration[7.0]
  def up
    new_components = [:days_since_last_release, :rollout_changes]
    ReleaseIndex.all.each do |reldex|
      ReleaseIndexComponent::DEFAULT_COMPONENTS.slice(*new_components).each do |component, details|
        next if reldex.components.find_by(name: component.to_s)

        reldex.components.create!(
          name: component.to_s,
          weight: details[:default_weight],
          tolerable_unit: details[:tolerance_unit],
          tolerable_range: details[:default_tolerance]
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
