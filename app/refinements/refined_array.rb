module RefinedArray
  refine Array do
    def mean
      size.zero? ? 0 : sum(0.0) / size
    end
  end
end
