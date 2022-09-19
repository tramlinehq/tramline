class Installations::Response::Keys
  class << self
    NORMALIZE_MAP = {
      [:id] => :id,
      [:full_name, :name, :path_with_namespace] => :name
    }

    def normalize(map_list)
      map_list.map do |map|
        replaced_map = map.with_indifferent_access
        NORMALIZE_MAP.each do |matchable_keys, replacement|
          matchable_keys.map do |key|
            next unless replaced_map.key?(key)
            replaced_map[replacement] = replaced_map.delete(key)
          end
        end
        replaced_map
      end
    end
  end
end
