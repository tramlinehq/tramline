module HashRefinement
  refine Hash do
    def auto(*args)
      self.class.new(*args) { |hsh, key| hsh[key] = Hash.new(&hsh.default_proc) }
    end
  end
end
