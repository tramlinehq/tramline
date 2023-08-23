require "rails_helper"

describe ReleasePlatform do
  it "has a valid factory" do
    expect(create(:release_platform)).to be_valid
  end

  describe "#in_creation?" do
    it "returns true for a draft train" do
      train = create(:train, :draft)
      release_platform = create(:release_platform, train:)

      expect(release_platform).to be_in_creation
    end

    it "returns false for a draft train with at least one review and release step" do
      train = create(:train, :draft)
      release_platform = create(:release_platform, train:)
      _review_step = create(:step, :review, :with_deployment, release_platform:)
      _release_step = create(:step, :release, :with_deployment, release_platform:)

      expect(release_platform).not_to be_in_creation
    end

    it "returns false for an active train" do
      train = create(:train, :active)
      release_platform = create(:release_platform, train:)

      expect(release_platform).not_to be_in_creation
    end

    it "returns true when there is no release step" do
      train = create(:train, :draft)
      release_platform = create(:release_platform, train:)
      _review_step = create(:step, :review, :with_deployment, release_platform:)

      expect(release_platform).to be_in_creation
    end

    it "returns false when there is no review step but has release step" do
      train = create(:train, :draft)
      release_platform = create(:release_platform, train:)
      _release_step = create(:step, :release, :with_deployment, release_platform:)

      expect(release_platform).not_to be_in_creation
    end
  end

  describe "#valid_steps?" do
    it "is false when release step is not present" do
      release_platform = create(:release_platform)
      _review_step = create(:step, :review, :with_deployment, release_platform:)

      expect(release_platform.valid_steps?).to be(false)
    end

    it "is true when release step is present" do
      release_platform = create(:release_platform)
      _release_step = create(:step, :release, :with_deployment, release_platform:)

      expect(release_platform.valid_steps?).to be(true)
    end
  end
end
