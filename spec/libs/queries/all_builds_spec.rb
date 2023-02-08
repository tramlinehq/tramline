require "rails_helper"

describe Queries::AllBuilds, type: :model do
  describe "#call" do
    it "returns an ActiveRecord relation" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run = create(:releases_step_run, step:)
      create(:build_artifact, step_run:)

      expect(app.all_builds).to be_a(ActiveRecord::Relation)
    end

    it "return the correct number of builds" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run1 = create(:releases_step_run, step:)
      step_run2 = create(:releases_step_run, step:)
      create(:build_artifact, step_run: step_run1)
      create(:build_artifact, step_run: step_run2)

      expect(app.all_builds.size).to eq(2)
    end

    it "returns all the fields" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run = create(:releases_step_run, step:)
      create(:build_artifact, step_run:)

      expected_keys = [
        "version_name",
        "version_code",
        "build_generated_at",
        "release_status",
        "step_status",
        "train_name",
        "step_name",
        "release_completed_at",
        "ci_link",
        "train_step_runs_id"
      ]

      expect(app.all_builds.as_json(except: :id).first.keys)
        .to contain_exactly(*expected_keys)
    end
  end
end
