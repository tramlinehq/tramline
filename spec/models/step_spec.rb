require "rails_helper"

describe Step do
  it "has valid factory" do
    expect(create(:step, :with_deployment)).to be_valid
  end

  describe "#set_step_number" do
    context "with review steps" do
      it "sets number 1 if no steps" do
        step = build(:step, :review, :with_deployment)

        step.validate

        expect(step.step_number).to eq(1)
      end

      it "sets number after last review step if existing review steps" do
        release_platform = create(:release_platform)
        create(:step, :review, :with_deployment, release_platform:)
        create(:step, :review, :with_deployment, release_platform:)
        step = build(:step, :review, :with_deployment, release_platform:)

        step.validate

        expect(step.step_number).to eq(3)
      end

      it "sets the review step to be before if a release step already exists" do
        release_platform = create(:release_platform)
        release_step = create(:step, :release, :with_deployment, release_platform:)
        create(:step, :review, :with_deployment, release_platform:)
        step = build(:step, :review, :with_deployment, release_platform:)

        step.validate
        release_step.reload

        expect(step.step_number).to eq(2)
        expect(release_step.step_number).to eq(3)
      end
    end

    context "with release step" do
      it "sets number 1 if no steps" do
        step = build(:step, :release, :with_deployment)

        step.validate

        expect(step.step_number).to eq(1)
      end

      it "sets number after last review step if existing review steps" do
        release_platform = create(:release_platform)
        create(:step, :review, :with_deployment, release_platform:)
        create(:step, :review, :with_deployment, release_platform:)
        step = build(:step, :release, :with_deployment, release_platform:)

        step.validate

        expect(step.step_number).to eq(3)
      end
    end
  end

  describe "#next" do
    let(:release_platform) { create(:release_platform) }
    let(:steps) { create_list(:step, 5, :with_deployment, release_platform: release_platform) }

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
      step = build(:step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.size).to eq(2)
    end

    it "adds incremented deployment numbers to created deployments" do
      step = build(:step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.pluck(:deployment_number)).to contain_exactly(1, 2)
    end

    it "validates release suffix to be valid if present" do
      app = create(:app, :android)
      release_platform = create(:release_platform, app: app)
      step = build(:step, :with_deployment, release_platform: release_platform, release_suffix: "%^&")

      step.save

      expect(step.persisted?).to be(false)
      expect(step.errors).to contain_exactly("Release suffix → only allows letters and underscore")
    end

    it "allows release suffix to be nil for ios apps" do
      app = create(:app, :ios)
      release_platform = create(:release_platform, app: app)
      step = build(:step, :with_deployment, release_platform:, release_suffix: nil)

      step.save

      expect(step.persisted?).to be(true)
      expect(step.errors).to be_empty
    end

    it "allows release suffix to be nil for android apps" do
      app = create(:app, :android)
      release_platform = create(:release_platform, app: app)
      step = build(:step, :with_deployment, release_platform:, release_suffix: nil)

      step.save

      expect(step.persisted?).to be(true)
      expect(step.errors).to be_empty
    end
  end

  describe "#active_deployments_for" do
    let(:release_platform) { create(:release_platform) }
    let(:train) { release_platform.train }

    it "returns all non-discarded deployments when no release is passed in" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      next_deployment = create(:deployment, step:)
      _discarded_deployment = create(:deployment, discarded_at: Time.current, step:)

      step.reload
      expect(step.active_deployments_for(nil)).to contain_exactly(step.deployments.first, next_deployment)
    end

    it "returns deployments that were available in the past releases" do
      two_days_ago = 2.days.ago
      two_hours_ago = 2.hours.ago
      four_hours_ago = 2.hours.ago
      step = travel_to(two_days_ago) { create(:step, :with_deployment, release_platform: release_platform) }
      d1 = create(:deployment, step:, created_at: two_days_ago)
      d2 = create(:deployment, step:, created_at: two_days_ago)
      old_release = create(:release, train:, scheduled_at: four_hours_ago, completed_at: two_hours_ago)

      d2.discard!

      step.reload
      expect(step.active_deployments_for(old_release)).to contain_exactly(step.deployments.first, d1, d2)
    end

    it "returns deployments active at the duration of the release" do
      two_days_ago = 2.days.ago
      step = travel_to(two_days_ago) { create(:step, :with_deployment, release_platform: release_platform) }
      d1 = create(:deployment, step:, created_at: two_days_ago)
      d2 = create(:deployment, step:, created_at: two_days_ago)

      travel_to(1.minute.ago) { d2.discard! }
      current_release = create(:release, train:, scheduled_at: Time.current)

      step.reload
      expect(step.active_deployments_for(current_release)).to contain_exactly(step.deployments.first, d1)
    end

    it "returns deployments that will be available for a new future release" do
      two_days_ago = 2.days.ago
      two_hours_later = 2.hours.from_now
      four_hours_later = 4.hours.from_now
      step = travel_to(two_days_ago) { create(:step, :with_deployment, release_platform: release_platform) }
      d1 = create(:deployment, step:, created_at: two_days_ago)
      d2 = create(:deployment, step:, created_at: two_days_ago)
      future_release = create(:release, train:, scheduled_at: two_hours_later, completed_at: four_hours_later)

      travel_to(1.minute.ago) do
        d1.discard!
        d2.discard!
      end

      d3 = create(:deployment, step:)

      expect(step.active_deployments_for(future_release)).to contain_exactly(step.deployments.first, d3)
    end

    it "returns all point-in-time deployments for the step when a step run is passed in" do
      two_days_ago = 2.days.ago
      step = travel_to(two_days_ago) { create(:step, :with_deployment, release_platform: release_platform) }
      d1 = create(:deployment, step:, created_at: two_days_ago)
      d2 = create(:deployment, step:, created_at: two_days_ago)
      current_release = create(:release, train:, scheduled_at: Time.current)
      release_platform_run = current_release.release_platform_runs.first
      step_run = create(:step_run, :success, step: step, release_platform_run:)
      create(:deployment_run, deployment: step.deployments.first, step_run: step_run)
      create(:deployment_run, deployment: d1, step_run: step_run)
      create(:deployment_run, deployment: d2, step_run: step_run)
      d2.discard!

      step.reload
      expect(step.active_deployments_for(current_release, step_run)).to contain_exactly(step.deployments.first, d1, d2)
    end
  end
end
