class V2::Reldex::StatusComponent < V2::Reldex::BaseComponent
  def initialize(release:, reldex_score:)
    raise ArgumentError, "reldex score is not a Score object" unless reldex_score.instance_of?(::ReleaseIndex::Score)
    @release = release
    @reldex_score = reldex_score
  end

  delegate :release_version, to: :@release

  def final_score
    number_to_human(@reldex_score.value, precision: 2, strip_insignificant_zeros: true)
  end

  def grade
    @reldex_score.grade
  end

  def tolerable_min
    @reldex_score.release_index.tolerable_range.min
  end

  def tolerable_max
    @reldex_score.release_index.tolerable_range.max
  end

  def components
    @reldex_score.components
  end

  def component_raw_value(component)
    unit = (component.release_index_component.tolerable_unit == "number") ? nil : component.release_index_component.tolerable_unit.pluralize
    builder = number_to_human(component.input_value, precision: 2, strip_insignificant_zeros: true)
    builder += " #{unit}" if unit
    builder
  end

  def grade_bg_color
    bg_color(grade)
  end

  def grade_color
    text_color(grade)
  end

  def component_grade_color(component)
    case component.range_value
    when 1
      bg_color(:excellent)
    when 0.5
      bg_color(:acceptable)
    when 0
      bg_color(:mediocre)
    else
      raise ArgumentError, "Invalid component value"
    end
  end
end
