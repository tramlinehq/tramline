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
          .select_paths(transforms.values)
          .transform_keys { |path| transforms.invert[path] }
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
  end
end
