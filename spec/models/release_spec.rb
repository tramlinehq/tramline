require "rails_helper"

describe Release do
  it "has a valid factory" do
    expect(create(:release)).to be_valid
  end

  describe ".create" do
    it "creates the release metadata with default locale" do
      run = create(:release)

      expect(run.release_metadata).to be_present
      expect(run.release_metadata.locale).to eq(ReleaseMetadata::DEFAULT_LOCALE)
      expect(run.release_metadata.release_notes).to eq(ReleaseMetadata::DEFAULT_RELEASE_NOTES)
    end
  end
end
