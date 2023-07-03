require "rails_helper"

describe Train do
  it "has a valid factory" do
    expect(create(:train)).to be_valid
  end

  describe "#bump_fix!" do
    it "updates the minor version if the current version is a partial semver" do
      train = create(:train, version_seeded_with: "1.2")
      _run = create(:release, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.4")
    end

    it "updates the patch version if the current version is a proper semver" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.1")
    end

    it "does not do anything if there are no runs" do
      train = create(:train, version_seeded_with: "1.2.1")

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.0")
    end
  end

  describe "#bump_release!" do
    it "updates the minor version" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.4.0")
    end

    it "updates the major version if a greater major version is specified" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_release!(true)
      train.reload

      expect(train.version_current).to eq("2.0.0")
    end

    it "does not do anything if there are no runs" do
      train = create(:train, version_seeded_with: "1.2.1")

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.3.0")
    end
  end

  describe "#create_release_platforms" do
    it "creates a release platform with android for android app" do
      app = create(:app, :android)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform with ios for ios app" do
      app = create(:app, :ios)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform per platform for cross-platform app" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(2)
      expect(train.reload.release_platforms.pluck(:platform)).to contain_exactly(*ReleasePlatform.platforms.keys)
    end
  end
end
