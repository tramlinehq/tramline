# frozen_string_literal: true

require "rails_helper"

describe DeleteVcsWebhookJob do
  let(:app) { create(:app, :android) }
  let(:vcs_provider) { instance_double(GithubIntegration, delete_webhook!: true) }

  describe "#perform" do
    it "deletes the webhook through the VCS provider of the app" do
      allow_any_instance_of(App).to receive(:vcs_provider).and_return(vcs_provider)

      described_class.new.perform(app.id, "1234")

      expect(vcs_provider).to have_received(:delete_webhook!).with("1234")
    end

    it "does nothing when the app no longer exists" do
      expect { described_class.new.perform(SecureRandom.uuid, "1234") }.not_to raise_error
    end

    it "does nothing when the app has no VCS provider anymore" do
      allow_any_instance_of(App).to receive(:vcs_provider).and_return(nil)

      expect { described_class.new.perform(app.id, "1234") }.not_to raise_error
    end
  end
end
