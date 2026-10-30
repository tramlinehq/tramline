require "rails_helper"

describe KeepAliveIntegrations::BitbucketJob do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, :with_bitbucket, integrable: app) }
  let(:bitbucket_integration) { integration.providable }
  let(:job) { described_class.new }

  before do
    bitbucket_integration
    allow(described_class).to receive(:perform_in)
    allow(job).to receive(:elog)
  end

  describe "#perform" do
    it "calls the api and schedules the next keepalive when connected" do
      allow_any_instance_of(BitbucketIntegration).to receive(:metadata).and_return({id: "{uuid}"})

      job.perform(bitbucket_integration.id)

      expect(described_class).to have_received(:perform_in).with(6.hours, bitbucket_integration.id)
    end

    it "checks again in 3 hours without calling the api when the integration needs reauth" do
      integration.update!(status: :needs_reauth)
      allow_any_instance_of(BitbucketIntegration).to receive(:metadata).and_raise("api should not be called")

      job.perform(bitbucket_integration.id)

      expect(job).not_to have_received(:elog)
      expect(described_class).to have_received(:perform_in).with(3.hours, bitbucket_integration.id)
    end

    it "stops when the integration is disconnected" do
      integration.update!(status: :disconnected)

      job.perform(bitbucket_integration.id)

      expect(described_class).not_to have_received(:perform_in)
    end

    it "keeps checking every 3 hours after a token refresh failure" do
      allow_any_instance_of(BitbucketIntegration).to receive(:metadata).and_raise(Installations::Error::TokenRefreshFailure)

      job.perform(bitbucket_integration.id)

      expect(job).to have_received(:elog).with(Installations::Error::TokenRefreshFailure, level: :warn)
      expect(described_class).to have_received(:perform_in).with(3.hours, bitbucket_integration.id)
    end

    it "retries in an hour on other api errors" do
      api_error = Installations::Error.new("API error", reason: :api_error)
      allow_any_instance_of(BitbucketIntegration).to receive(:metadata).and_raise(api_error)

      job.perform(bitbucket_integration.id)

      expect(job).to have_received(:elog).with(api_error, level: :error)
      expect(described_class).to have_received(:perform_in).with(1.hour, bitbucket_integration.id)
    end
  end

  it "is scheduled when a bitbucket integration is created" do
    new_integration = create(:integration, :with_bitbucket, integrable: create(:app, :android))

    expect(described_class).to have_received(:perform_in).with(6.hours, new_integration.providable.id)
  end
end
