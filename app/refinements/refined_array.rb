module RefinedArray
  refine Array do
    def zip_self = zip(self)
  end
end
