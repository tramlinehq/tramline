class V2::Reldex::BaseComponent < V2::BaseComponent
  def text_color(grade)
    case grade
    when :excellent
      "!text-reldexExcellent-800 !dark:text-reldexExcellent-300"
    when :acceptable
      "!text-reldexAcceptable-800 !dark:text-reldexAcceptable-300"
    when :mediocre
      "!text-reldexMediocre-800 !dark:text-reldexMediocre-300"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def bg_color(grade)
    case grade
    when :excellent
      "bg-reldexExcellent-100 dark:bg-reldexExcellent-900"
    when :acceptable
      "bg-reldexAcceptable-100 dark:bg-reldexAcceptable-900"
    when :mediocre
      "bg-reldexMediocre-100 dark:bg-reldexMediocre-900"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def slider_color(grade) = resolve_color(grade)
end
