module RefinedInteger
  refine Integer do
    def as_duration_with(unit:)
      ActiveSupport::Duration.parse(Duration.new(unit.to_sym => self).iso8601)
    end
  end
end
