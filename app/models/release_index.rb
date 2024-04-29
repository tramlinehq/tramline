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

  attr_accessor :tolerable_min, :tolerable_max

  after_initialize :set_defaults, if: :new_record?
  after_initialize :build_components, if: :new_record?
  after_initialize :set_tolerable_values, if: :persisted?

  accepts_nested_attributes_for :release_index_components
  validate :validate_weightage_sum
  validate :constrained_tolerable_range

  DEFAULT_TOLERABLE_RANGE = 0.5..0.8

  def score(**args)
    Score.compute(self, **args)
  end

  GRADES = [:excellent, :acceptable, :mediocre]

  class Score
    def self.compute(release_index, **args)
      new(release_index, **args)
    end

    def initialize(release_index, **args)
      @release_index = release_index
      args_keys = args.keys.to_set
      allowed_components = ReleaseIndexComponent::DEFAULT_COMPONENTS.keys.to_set
      raise ArgumentError, "Args do not match the valid reldex components" unless args_keys.subset?(allowed_components)
      @args = args
      @value = 0
      @components = []
      @grade = nil
      compute
    end

    attr_reader :value, :components, :release_index, :grade

    private

    def compute
      @release_index.components.where.not(weight: 0).find_each do |component|
        component_score = component.score(@args[component.name.to_sym])
        @value += component_score.value
        @components << component_score
      end

      @grade = compute_grade
    end

    def compute_grade
      if @value <= tolerable_range.begin
        GRADES[2]
      elsif @value >= tolerable_range.end
        GRADES[0]
      else
        GRADES[1]
      end
    end

    delegate :tolerable_range, to: :@release_index
  end

  private

  def set_defaults
    self.tolerable_range = DEFAULT_TOLERABLE_RANGE
  end

  def set_tolerable_values
    self.tolerable_min = tolerable_range.min
    self.tolerable_max = tolerable_range.max
  end

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
