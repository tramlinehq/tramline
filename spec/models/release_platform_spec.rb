require "rails_helper"

describe ReleasePlatform do
  it "has a valid factory" do
    expect(create(:release_platform)).to be_valid
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
