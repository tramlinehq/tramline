class V2::Reldex::BaseComponent < V2::BaseComponent
  COLORS = {
    dark: {
      excellent: "var(--color-excellent)",
      acceptable: "var(--color-acceptable)",
      mediocre: "var(--color-mediocre)"
    },
    light: {
      excellent: "var(--color-excellent)",
      acceptable: "var(--color-acceptable)",
      mediocre: "var(--color-mediocre)"
    }
  }

  def text_color(grade)
    case grade
    when :excellent
      "text-excellent-800 dark:text-excellent-300"
    when :acceptable
      "text-acceptable-800 dark:text-acceptable-300"
    when :mediocre
      "text-mediocre-800 dark:text-mediocre-300"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def bg_color(grade)
    case grade
    when :excellent
      "bg-excellent-100 dark:bg-excellent-900"
    when :acceptable
      "bg-acceptable-100 dark:bg-acceptable-900"
    when :mediocre
      "bg-mediocre-100 dark:bg-mediocre-900"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def slider_color(grade, theme = :light)
    COLORS[theme][grade]
  end
end
