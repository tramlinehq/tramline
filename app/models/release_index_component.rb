# == Schema Information
#
# Table name: release_index_components
#
#  id               :uuid             not null, primary key
#  name             :string           not null, indexed => [release_index_id]
#  tolerable_range  :numrange         not null
#  tolerable_unit   :string           not null
#  weight           :decimal(4, 3)    not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  release_index_id :uuid             not null, indexed => [name], indexed
#
class ReleaseIndexComponent < ApplicationRecord
  using RefinedArray
  include Displayable

  TOLERANCE_UNITS = [:day, :number]

  DEFAULT_COMPONENTS = {
    hotfixes: {default_weight: 0.30, default_tolerance: 0..1, tolerance_unit: :number},
    rollout_fixes: {default_weight: 0.20, default_tolerance: 1..2, tolerance_unit: :number},
    rollout_duration: {default_weight: 0.15, default_tolerance: 7..10, tolerance_unit: :day},
    duration: {default_weight: 0.05, default_tolerance: 14..17, tolerance_unit: :day},
    stability_duration: {default_weight: 0.15, default_tolerance: 7..10, tolerance_unit: :day},
    stability_changes: {default_weight: 0.15, default_tolerance: 10..20, tolerance_unit: :number},
    rollout_changes: {default_weight: 0, default_tolerance: 1..5, tolerance_unit: :number},
    days_since_last_release: {default_weight: 0, default_tolerance: 10..15, tolerance_unit: :day}
  }

  DEFAULT_COMPONENTS.each do |component, details|
    tolerance_unit = details[:tolerance_unit]
    unless TOLERANCE_UNITS.include?(tolerance_unit)
      raise ArgumentError, "Invalid tolerance unit '#{tolerance_unit}' used in component '#{component}'"
    end
  end

  belongs_to :release_index
  enum name: DEFAULT_COMPONENTS.keys.map(&:to_s).zip_map_self
  enum tolerable_unit: TOLERANCE_UNITS.map(&:to_s).zip_map_self

  attr_accessor :tolerable_min, :tolerable_max, :weight_percentage

  validates :name, uniqueness: {scope: :release_index_id}

  after_initialize :set_tolerable_values, if: :persisted?

  def set_tolerable_values
    self.tolerable_min = tolerable_range.min.to_i
    self.tolerable_max = tolerable_range.max.to_i
    self.weight_percentage = weight * 100
  end

  def description
    I18n.t("activerecord.values.release_index_component.description.#{name}")
  end

  def score(value)
    Score.new(self, value)
  end

  class Score
    def initialize(component, input_value)
      @release_index_component = component
      @input_value = input_value
    end

    attr_reader :release_index_component, :input_value

    def value
      range_value * weight
    end

    def range_value
      if @input_value <= tolerable_range.begin
        1
      elsif @input_value >= tolerable_range.end
        0
      else
        0.5
      end
    end

    delegate :tolerable_range, :weight, to: :@release_index_component
  end
end
