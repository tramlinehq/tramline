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
  belongs_to :train
  has_many :release_index_components, dependent: :destroy
  alias_method :components, :release_index_components

  after_initialize :build_components, if: :new_record?
  validate :validate_weightage_sum
  validate :constrained_tolerable_range

  def score(**args)
    Score.new(self, **args)
  end

  GRADES = [:great, :acceptable, :mediocre]

  class Score
    def initialize(release_index, **args)
      @release_index = release_index
      args_keys = args.keys.to_set
      allowed_components = ReleaseIndexComponent::DEFAULT_COMPONENTS.keys.to_set
      raise ArgumentError, "Args do not match the valid reldex components" unless args_keys.subset?(allowed_components)
      @args = args
    end

    delegate :tolerable_range, to: :@release_index

    def value
      @value ||= @release_index.components.sum do |component|
        component.score(@args[component.name.to_sym])
      end
    end

    def grade
      if value < tolerable_range.begin
        GRADES[0]
      elsif tolerable_range.cover?(value)
        GRADES[1]
      else
        GRADES[2]
      end
    end
  end

  private

  def build_components
    ReleaseIndexComponent::DEFAULT_COMPONENTS.each do |component, details|
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
      errors.add(:base, "total weightage of components must be equal 100%")
    end
  end

  def constrained_tolerable_range
    if tolerable_range.begin < 0 || tolerable_range.end > 1
      errors.add(:tolerable_range, "must be within 0 and 1")
    end
  end
end
