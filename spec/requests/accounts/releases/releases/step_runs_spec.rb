require "rails_helper"

RSpec.describe "Accounts::Releases::Releases::StepRuns", type: :request do
  let(:release) { create(:releases_train_run) }
  let(:organization) { create(:organization) }
  let(:user) { create(:accounts_user, confirmed_at: Time.zone.now, organizations: [organization]) }
  let(:step) { create(:releases_step, train: release.train) }

  describe "POST /start" do
    xit "start the step" do
      sign_in user
      post start_release_step_run_path(release, step)
      expect(step.status).to be_eql("on_track")
    end
  end
end
