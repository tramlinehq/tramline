require "rails_helper"

RSpec.describe "Accounts::Releases::Releases::StepRuns", type: :request do
  let(:release) { create(:releases_train_run) }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :as_developer, confirmed_at: Time.now, member_organization: organization) }
  let(:step) { create(:releases_step, :with_deployment, train: release.train) }

  describe "POST /start" do
    xit "start the step" do
      sign_in user
      post start_release_step_run_path(release, step)
      expect(step.status).to be_eql("on_track")
    end
  end
end
