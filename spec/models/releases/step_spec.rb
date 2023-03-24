require "rails_helper"

describe Releases::Step do
  it "has valid factory" do
    expect(create(:releases_step, :with_deployment)).to be_valid
  end

  describe "#set_step_number" do
    context "with review steps" do
      it "sets number 1 if no steps" do
        step = build(:releases_step, :review, :with_deployment)

        step.validate

        expect(step.step_number).to eq(1)
      end

      it "sets number after last review step if existing review steps" do
        train = create(:releases_train)
        create(:releases_step, :review, :with_deployment, train:)
        create(:releases_step, :review, :with_deployment, train:)
        step = build(:releases_step, :review, :with_deployment, train:)

        step.validate

        expect(step.step_number).to eq(3)
      end

      it "sets the review step to be before if a release step already exists" do
        train = create(:releases_train)
        release_step = create(:releases_step, :release, :with_deployment, train:)
        create(:releases_step, :review, :with_deployment, train:)
        step = build(:releases_step, :review, :with_deployment, train:)

        step.validate
        release_step.reload

        expect(step.step_number).to eq(2)
        expect(release_step.step_number).to eq(3)
      end
    end

    context "with release step" do
      it "sets number 1 if no steps" do
        step = build(:releases_step, :release, :with_deployment)

        step.validate

        expect(step.step_number).to eq(1)
      end

      it "sets number after last review step if existing review steps" do
        train = create(:releases_train)
        create(:releases_step, :review, :with_deployment, train:)
        create(:releases_step, :review, :with_deployment, train:)
        step = build(:releases_step, :release, :with_deployment, train:)

        step.validate

        expect(step.step_number).to eq(3)
      end
    end
  end

  describe "#next" do
    let(:train) { create(:releases_train) }
    let(:steps) { create_list(:releases_step, 5, :with_deployment, train: train) }

    it "returns next element" do
      first_step = steps.first
      expect(first_step.next).to be_eql(steps.second)
    end

    it "returns nil for final element" do
      expect(steps.last.next).to be_nil
    end
  end

  describe "#create" do
    it "saves deployments along with it" do
      step = build(:releases_step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.size).to eq(2)
    end

    it "adds incremented deployment numbers to created deployments" do
      step = build(:releases_step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.pluck(:deployment_number)).to contain_exactly(1, 2)
    end

    it "validates presence of release suffix for android apps" do
      app = create(:app, :android)
      train = create(:releases_train, app: app)
      step = build(:releases_step, :with_deployment, train: train, release_suffix: nil)

      step.save

      expect(step.persisted?).to be(false)
      expect(step.errors).to contain_exactly("release suffix →\ncan't be blank")
    end

    it "validates release suffix to be valid for android apps" do
      app = create(:app, :android)
      train = create(:releases_train, app: app)
      step = build(:releases_step, :with_deployment, train: train, release_suffix: "%^&")

      step.save

      expect(step.persisted?).to be(false)
      expect(step.errors).to contain_exactly("release suffix →\nonly allows letters and underscore")
    end

    it "allows release suffix to be nil for ios apps" do
      app = create(:app, :ios)
      train = create(:releases_train, app: app)
      step = build(:releases_step, :with_deployment, train: train, release_suffix: nil)

      step.save

      expect(step.persisted?).to be(true)
      expect(step.errors).to be_empty
    end
  end
end
