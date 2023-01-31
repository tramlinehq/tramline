require "rails_helper"

describe Queries::AllBuilds, type: :model do
  describe "#call" do
    it "returns all the fields" do
      apps = 2.times.map do
        app = create(:app, :android)
        train = create(:releases_train, app:)
        step = create(:releases_step, :with_deployment, train:)
        step_run = create(:releases_step_run, step:)
        create(:build_artifact, step_run:)
        app
      end

      expect(apps[0].all_builds.first.keys)
        .to contain_exactly(:version_name, :version_code, :build_generated_at, :train_name, :step_name)

      expect(apps[1].all_builds.first.keys)
        .to contain_exactly(:version_name, :version_code, :build_generated_at, :train_name, :step_name)
    end
  end
end
