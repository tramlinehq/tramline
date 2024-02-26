module RefinedInteger
  refine Integer do
    def as_duration_with(unit:)
      ActiveSupport::Duration.parse(Duration.new(unit.to_sym => self).iso8601)
    end

    def humanize_duration
      return if zero? || blank?

      ActiveSupport::Duration.build(self).parts.except(:seconds).collect do |key, val|
        I18n.t("datetime.distance_in_words.x_#{key}", count: val)
      end.join(", ")
    end
  end
end
