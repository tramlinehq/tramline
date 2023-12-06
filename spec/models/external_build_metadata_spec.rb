require "rails_helper"

describe ExternalBuildMetadata do
  it "has valid factory" do
    expect(create(:external_build_metadata)).to be_valid
  end

  describe "#update_or_insert!" do
    let(:step_run) { create(:step_run) }
    let(:metadata) { [{identifier: "foo", value: 100, type: "number"}.with_indifferent_access] }
    let(:updated_metadata) {
      [{identifier: "foo", value: 200, type: "number"}.with_indifferent_access,
        {identifier: "bar", value: 100, type: "number"}.with_indifferent_access]
    }

    it "creates new record" do
      external_build_metadata = build(:external_build_metadata, step_run:)

      persisted_metadata = external_build_metadata.update_or_insert!(metadata)

      expect(persisted_metadata.reload.metadata.values).to match_array(metadata)
    end

    it "updates existing record" do
      existing_metadata = create(:external_build_metadata, step_run:, metadata: metadata.index_by { |k| k[:identifier] })

      existing_metadata.update_or_insert!(updated_metadata)

      expect(existing_metadata.reload.metadata.values).to match_array(updated_metadata)
    end
  end
end
