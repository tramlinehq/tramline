require "rails_helper"

describe ReleasePlatform do
  it "has a valid factory" do
    expect(create(:release_platform)).to be_valid
  end

  context "with draft mode" do
    let(:release_platform) { create(:release_platform, :draft) }

    it "allows creating steps" do
      create(:step, :with_deployment, release_platform: release_platform)
      expect(release_platform.reload.steps.size).to be(1)
    end
  end

  describe "#activate!" do
    let(:release_platform) { create(:release_platform, :draft) }

    it "disallows creating more than one release step" do
      build(:step, :release, :with_deployment, release_platform: release_platform)
      build(:step, :release, :with_deployment, release_platform: release_platform)

      expect { release_platform.activate! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows creating multiple review steps" do
      create(:step, :review, :with_deployment, release_platform: release_platform)
      create(:step, :review, :with_deployment, release_platform: release_platform)
      create(:step, :release, :with_deployment, release_platform: release_platform)

      expect(release_platform.activate!).to be(true)
      expect(release_platform.errors).to be_empty
      expect(release_platform.reload.active?).to be(true)
    end
  end
end
