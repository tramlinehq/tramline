module RefinedArray
  refine Array do
    def zip_map_self = zip(self).to_h
  end
end
