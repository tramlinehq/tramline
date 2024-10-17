require "rails_helper"

describe VersioningStrategies::Codes do
  describe "#bump" do
    context "when strategy: increment" do
      it "increments the value" do
        version_code = described_class.new({value: 1, release_version: nil})
        expect(version_code.bump(strategy: :increment)).to eq(2)
      end

      it "works on self as well" do
        params = {value: 100, release_version: nil}
        expect(described_class.bump(params, strategy: :increment)).to eq(101)
      end
    end

    context "when strategy: semver_pairs_with_build_sequence" do
      [
        [9_03_48_00_00, "3.48.0", 9_03_48_00_01],
        [9_03_48_00_00, "3.48.10", 9_03_48_10_00],
        [9_08_08_00_00, "8.8.1", 9_08_08_01_00],
        [9_01_00_00_00, "1.0.0", 9_01_00_00_01],
        [9_08_08_01_10, "8.8.1", 9_08_08_01_11],
        [9_08_09_48_10, "8.9.48", 9_08_09_48_11],
        [9_08_08_00_75, "8.8.1", 9_08_08_01_00]
      ].each do |previous_number, version, expected|
        it "increments the value for #{previous_number}" do
          version_code = described_class.new({value: previous_number, release_version: version})
          expect(version_code.bump(strategy: :semver_pairs_with_build_sequence)).to eq(expected)
        end
      end
    end
  end
end
