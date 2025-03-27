require "rails_helper"

Either = Installations::Response::Keys::Either
describe Installations::Response::Keys do
  describe ".transform" do
    let!(:test_cases) {
      [
        [
          [{key1: 1, key2: 2}],
          {new_key1: :key1, new_key2: :key2},
          [{new_key1: 1, new_key2: 2}]
        ],
        [
          [{key1: 1, key2: {nested_key: 2}}],
          {new_key1: :key1, new_key2: [:key2, :nested_key]},
          [{new_key1: 1, new_key2: 2}]
        ],
        [
          [key1: 1, key2: 2],
          {new_key1: :key1},
          [{new_key1: 1}]
        ],
        [
          [{key1: 1, key2: [{nested_key: 2}, {nested_key: 3}]}],
          {new_key1: :key1, new_key2: {key2: {new_nested_key: :nested_key}}},
          [{new_key1: 1, new_key2: [{new_nested_key: 2}, {new_nested_key: 3}]}]
        ],
        [
          [{key1: 1, key2: {nested_key: 2}}],
          {new_key1: :key1,
           new_key2: [:key2, :nested_key],
           new_keys3: [:invalid_key, :invalid_nested_key]},
          [{"new_key1" => 1, "new_key2" => 2, "new_keys3" => nil}]
        ],
        [
          [{key1: 1, key2: 2, key3: 3}],
          {new_key1: :key1,
           new_key2: Either.new(:key2, :key3),
           new_key3: Either.new(:key3, :key2),
           new_key4: Either.new(:key4, :key2)},
          [{"new_key1" => 1, "new_key2" => 2, "new_key3" => 3, "new_key4" => 2}]
        ]
      ]
    }

    it "transforms the map according to the transformations" do
      test_cases.each do |input_map, transforms, expected_map|
        result = described_class.transform(input_map, transforms)[0]
        expect(result).to match(expected_map[0])
      end
    end
  end
end
