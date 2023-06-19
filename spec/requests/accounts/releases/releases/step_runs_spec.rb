require "rails_helper"

describe "Accounts::Releases::Releases::StepRuns" do
  let(:release) { create(:release_platform_run) }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }
  let(:step) { create(:step, :with_deployment, release_platform: release.release_platform) }

  describe "POST /start" do
    it "start the step" do
      skip "not implemented yet"

      sign_in user
      post start_release_step_run_path(release, step)
      expect(step.status).to be_eql("on_track")
    end
  end
end
