module RefinedHash
  refine Hash do
    def infinite(*args)
      self.class.new(*args) { |new_hash, missing_key| new_hash[missing_key] = new(&new_hash.default_proc) }
    end
  end
end
