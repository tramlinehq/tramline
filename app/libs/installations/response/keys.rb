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
          .deep_slice(transforms.values)
          .transform_keys { |path| transforms.invert[path] }
          .with_indifferent_access
      end
    end
  end
end
