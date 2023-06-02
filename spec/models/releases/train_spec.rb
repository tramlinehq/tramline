require "rails_helper"

describe Releases::Train do
  it "has a valid factory" do
    expect(create(:releases_train)).to be_valid
  end

  context "with draft mode" do
    let(:train) { create(:releases_train, :draft) }

    it "allows creating steps" do
      create(:releases_step, :with_deployment, train: train)
      expect(train.reload.steps.size).to be(1)
    end
  end

  describe "#activate!" do
    let(:train) { create(:releases_train, :draft) }

    it "disallows creating more than one release step" do
      build(:releases_step, :release, :with_deployment, train: train)
      build(:releases_step, :release, :with_deployment, train: train)

      expect { train.activate! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows creating multiple review steps" do
      create(:releases_step, :review, :with_deployment, train: train)
      create(:releases_step, :review, :with_deployment, train: train)
      create(:releases_step, :release, :with_deployment, train: train)

      expect(train.activate!).to be(true)
      expect(train.errors).to be_empty
      expect(train.reload.active?).to be(true)
    end
  end

  describe "#bump_fix!" do
    it "updates the minor version if the current version is a partial semver" do
      train = create(:releases_train, version_seeded_with: "1.2")
      _run = create(:releases_train_run, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.4")
    end

    it "updates the patch version if the current version is a proper semver" do
      train = create(:releases_train, version_seeded_with: "1.2.1")
      _run = create(:releases_train_run, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.1")
    end

    it "does not do anything if there are no runs" do
      train = create(:releases_train, version_seeded_with: "1.2.1")

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.0")
    end
  end

  describe "#bump_release!" do
    it "updates the minor version" do
      train = create(:releases_train, version_seeded_with: "1.2.1")
      _run = create(:releases_train_run, train:)

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.4.0")
    end

    it "updates the major version if a greater major version is specified" do
      train = create(:releases_train, version_seeded_with: "1.2.1")
      _run = create(:releases_train_run, train:)

      train.bump_release!(true)
      train.reload

      expect(train.version_current).to eq("2.0.0")
    end

    it "does not do anything if there are no runs" do
      train = create(:releases_train, version_seeded_with: "1.2.1")

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.3.0")
    end
  end
end
