class Installations::Response::Keys
  class << self
    using RefinedHash

    class MissingTransformationsError < ArgumentError; end

    MAPPERS = {
      default: {
        [:id, :slug] => :id,
        [:full_name, :name, :path_with_namespace, :title] => :name
      },

      workflow_runs: {
        [:id, :build_slug] => :ci_ref,
        [:html_url, :build_url] => :ci_link
      }
    }

    # TODO: DEPRECATE THIS
    def normalize(map_list, mapper = nil)
      return [] if map_list.blank?

      map_list.map do |map|
        replaced_map = map.with_indifferent_access

        choose_mapper(mapper).each do |matchable_keys, replacement|
          matchable_keys.map do |key|
            next unless replaced_map.key?(key)
            replaced_map[replacement] = replaced_map.delete(key)
          end
        end

        replaced_map
      end
    end

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

    private

    def choose_mapper(mapper)
      mapper ? MAPPERS[mapper] : MAPPERS[:default]
    end
  end
end
