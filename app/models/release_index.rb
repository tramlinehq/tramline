# == Schema Information
#
# Table name: release_indices
#
#  id              :uuid             not null, primary key
#  tolerable_range :numrange         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  train_id        :uuid             not null, indexed
#
class ReleaseIndex < ApplicationRecord
  TOLERANCE_UNITS = [:day, :number]

  COMPONENTS = {
    hotfixes: {default_weight: 0.30, default_tolerance: 0..1, tolerance_unit: :number},
    rollout_fixes: {default_weight: 0.20, default_tolerance: 1..2, tolerance_unit: :number},
    rollout_duration: {default_weight: 0.15, default_tolerance: 7..10, tolerance_unit: :day},
    review_duration: {default_weight: 0.05, default_tolerance: 1..3, tolerance_unit: :day},
    stability_duration: {default_weight: 0.15, default_tolerance: 5..10, tolerance_unit: :day},
    stability_changes: {default_weight: 0.15, default_tolerance: 10..20, tolerance_unit: :number}
  }

  COMPONENTS.each do |component, details|
    tolerance_unit = details[:tolerance_unit]
    unless TOLERANCE_UNITS.include?(tolerance_unit)
      raise ArgumentError, "Invalid tolerance unit '#{tolerance_unit}' used in component '#{component}'"
    end
  end

  COMPONENT_MULTIPLIERS = {
    great: 1,
    acceptable: 0.5,
    mediocre: 0
  }

  belongs_to :train
  has_many :release_index_components, dependent: :destroy
  alias_method :components, :release_index_components

  after_initialize :create_components
  validate :validate_weightage_sum
  validate :constrained_tolerable_range

  private

  def create_components
    return unless new_record?

    COMPONENTS.each do |component, details|
      components.build(
        name: component.to_s,
        tolerable_range: details[:default_tolerance],
        tolerable_unit: details[:tolerance_unit],
        weight: details[:default_weight]
      )
    end
  end

  def validate_weightage_sum
    total_weight = components.sum(&:weight)
    unless (total_weight - 1.000).abs < 0.001
      errors.add(:base, "The total weightage of components must be equal 100%")
    end
  end

  def constrained_tolerable_range
    if tolerable_range.begin < 0 || tolerable_range.end > 1
      errors.add(:tolerable_range, "must be within 0 and 1")
    end
  end
end
