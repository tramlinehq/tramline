class V2::ReldexStatusComponent < V2::BaseComponent
  def initialize(release:, reldex_score:)
    raise ArgumentError, "reldex score is not a Score object" unless reldex_score.instance_of?(::ReleaseIndex::Score)
    @release = release
    @reldex_score = reldex_score
  end

  def final_score
    @reldex_score.value
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

  def grade_color
    case grade
    when :great
      "text-green-800 dark:text-green-300"
    when :acceptable
      "text-sky-800 dark:text-sky-300"
    when :mediocre
      "text-rose-800 dark:text-rose-300"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def grade_bg_color
    case grade
    when :great
      "bg-green-100 dark:bg-green-900"
    when :acceptable
      "bg-sky-100 dark:bg-sky-900"
    when :mediocre
      "bg-rose-100 dark:bg-rose-900"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def components
    @reldex_score.components
  end

  def component_raw_value(component)
    unit = (component.release_index_component.tolerable_unit == "number") ? nil : component.release_index_component.tolerable_unit.pluralize
    builder = component.input_value.to_s
    builder += " #{unit}" if unit
    builder
  end

  delegate :release_version, to: :@release
end
