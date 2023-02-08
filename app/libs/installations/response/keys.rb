class Installations::Response::Keys
  class << self
    using RefinedHash

    class MissingTransformationsError < ArgumentError; end

    def transform(responses, transforms)
      raise MissingTransformationsError if transforms.blank?
      return [] if responses.blank?

      responses.map do |response|
        response
          .to_h
          .with_indifferent_access
          .then { |m| transform_paths(m, transforms) }
          .with_indifferent_access
          .then { |resp| default_coercions(resp) }
      end
    end

    private

    def default_coercions(response)
      response
        .update_key(:id, &:to_s)
        .update_key(:name, &:to_s)
    end

    def transform_path(in_m, path, path_key)
      if path.is_a?(Hash)
        raise ArgumentError, "Invalid transformation" if path.size > 1
        [path_key, in_m.get_in(*path.keys.first).map { |m| transform_paths(m, path.values.first) }]
      else
        [path_key, in_m.get_in(*path)]
      end
    end

    def transform_paths(m, transforms)
      transforms.to_h { |k, v| transform_path(m, v, k) }
    end
  end
end
