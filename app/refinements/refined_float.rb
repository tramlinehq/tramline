module RefinedFloat
  refine Float do
    # instead of using direct equality for floats, use a tolerance threshold to check if two
    # floating-point numbers are "close enough" to be considered equal
    def equal_to?(other)
      (self - other).abs < Float::EPSILON
    end
  end
end
