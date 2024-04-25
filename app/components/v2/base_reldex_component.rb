class V2::BaseReldexComponent < V2::BaseComponent
  COLORS = {
    dark: {
      excellent: "#14532d",
      acceptable: "#0c4a6e",
      mediocre: "#881337"
    },
    light: {
      excellent: "#bbf7d0",
      acceptable: "#bae6fd",
      mediocre: "#fecdd3"
    }
  }

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
      "bg-green-100 dark:bg-green-800"
    when :acceptable
      "bg-sky-100 dark:bg-sky-800"
    when :mediocre
      "bg-rose-100 dark:bg-rose-800"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def bg_color(grade)
    case grade
    when :excellent
      "bg-green-100 dark:bg-green-900"
    when :acceptable
      "bg-sky-100 dark:bg-sky-900"
    when :mediocre
      "bg-rose-100 dark:bg-rose-900"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  def slider_color(grade, theme = :light)
    COLORS[theme][grade]
  end
end
