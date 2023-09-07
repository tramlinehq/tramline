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

    def get_in(*path)
      path.reduce(self) do |acc, key|
        acc&.fetch(key, nil)
      rescue ArgumentError, IndexError => e
        raise UndefinedPathError, "Could not fetch path (#{path.join(" > ")}) at #{key} for #{e.class}", e.backtrace
      end
    end

    def merge_if_present(params)
      present? ? merge(params) : self
    end
  end
end
