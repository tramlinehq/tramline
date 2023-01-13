module RefinedHash
  class UndefinedPathError < StandardError; end

  refine Hash do
    def update_key(key, &_blk)
      value = fetch(key, nil)

      unless value.nil?
        copy = dup
        copy[key] = yield(value)
        return copy
      end

      self
    end

    def select_paths(paths)
      paths.index_with { |path| get_in(*path) }
    end

    def get_in(*path)
      path.reduce(self) do |acc, key|
        acc.fetch(key)
      rescue ArgumentError, IndexError, NoMethodError => e
        raise UndefinedPathError, "Could not fetch path (#{path.join(" > ")}) at #{key}", e.backtrace
      end
    end
  end
end
