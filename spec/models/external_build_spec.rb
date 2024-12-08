require "rails_helper"

describe ExternalBuild do
  it "has valid factory" do
    expect(create(:external_build)).to be_valid
  end

  describe "#update_or_insert!" do
    let(:test_build) { create(:build) }
    let(:metadata) { [{identifier: "foo", value: 100, type: "number"}.with_indifferent_access] }
    let(:invalid_metadata) { [{value: 100, type: "number"}.with_indifferent_access] }
    let(:updated_metadata) {
      [{identifier: "foo", value: 200, type: "number"}.with_indifferent_access,
        {identifier: "bar", value: 100, type: "number"}.with_indifferent_access]
    }

    it "creates new record" do
      external_build_metadata = build(:external_build, build: test_build)

      persisted_metadata = external_build_metadata.update_or_insert!(metadata)

      expect(persisted_metadata.reload.metadata.values).to match_array(metadata)
    end

    it "updates existing record" do
      existing_metadata = create(:external_build, build: test_build, metadata: metadata.index_by { |k| k[:identifier] })

      existing_metadata.update_or_insert!(updated_metadata)

      expect(existing_metadata.reload.metadata.values).to match_array(updated_metadata)
    end

    it "validates the metadata" do
      external_build_metadata = build(:external_build, build: test_build)

      persisted_metadata = external_build_metadata.update_or_insert!(invalid_metadata)

      expect(persisted_metadata.errors).to contain_exactly("Metadata → The property '#/0' did not contain a required property of 'identifier'")
      expect(persisted_metadata.id).to be_nil
    end
  end
end
