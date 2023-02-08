require "rails_helper"

describe Installations::Response::Keys do
  describe ".transform" do
    let!(:test_cases) {
      [
        [[{key1: 1, key2: 2}],
          {new_key1: :key1, new_key2: :key2},
          [{new_key1: 1, new_key2: 2}]],
        [[{key1: 1, key2: {nested_key: 2}}],
          {new_key1: :key1, new_key2: [:key2, :nested_key]},
          [{new_key1: 1, new_key2: 2}]],
        [[key1: 1, key2: 2],
          {new_key1: :key1},
          [{new_key1: 1}]],
        [[{key1: 1, key2: [{nested_key: 2}, {nested_key: 3}]}],
          {new_key1: :key1, new_key2: {key2: {new_nested_key: :nested_key}}},
          [{new_key1: 1, new_key2: [{new_nested_key: 2}, {new_nested_key: 3}]}]]
      ]
    }

    it "transforms the map according to the transformations" do
      test_cases.each do |input_map, transforms, expected_map|
        expect(described_class.transform(input_map, transforms)).to match_array(expected_map)
      end
    end
  end
end
