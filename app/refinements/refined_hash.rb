module RefinedHash
  class UndefinedPathError < StandardError; end

  refine Hash do
    def deep_slice(paths)
      paths.index_with do |path|
        deep_fetch(*path)
      end
    end

    def deep_fetch(*path)
      path.reduce(self) do |acc, key|
        acc.fetch(key)
      rescue ArgumentError, IndexError, NoMethodError => e
        raise UndefinedPathError, "Could not fetch path (#{path.join(" > ")}) at #{key}", e.backtrace
      end
    end
  end
end
