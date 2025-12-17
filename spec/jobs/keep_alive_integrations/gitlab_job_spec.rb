# frozen_string_literal: true

require "rails_helper"

describe KeepAliveIntegrations::GitlabJob do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :android, organization: organization) }
  let(:integration) { create(:integration, category: "version_control", integrable: app, status: :connected, providable: create(:gitlab_integration, :without_callbacks_and_validations)) }
  let(:gitlab_integration) { integration.providable }
  let(:job) { described_class.new }

  before do
    # Ensure gitlab integration is pre-created to avoid verifying callbacks
    gitlab_integration

    allow(described_class).to receive(:perform_in)
    allow_any_instance_of(described_class).to receive(:elog)
  end

  describe "#perform" do
    context "when integration is connected" do
      it "calls user_info and schedules next keepalive" do
        allow_any_instance_of(GitlabIntegration).to receive(:user_info).and_return({id: 123, username: "test"})

        job.perform(gitlab_integration.id)

        expect(described_class).to have_received(:perform_in).with(6.hours, gitlab_integration.id)
      end
    end

    context "when integration is not connected" do
      before { integration.update!(status: :disconnected) }

      it "exits early without calling user_info or scheduling" do
        allow_any_instance_of(GitlabIntegration).to receive(:user_info)

        job.perform(gitlab_integration.id)

        expect(described_class).not_to have_received(:perform_in)
      end
    end

    context "when integration is in needs_reauth status" do
      before { integration.update!(status: :needs_reauth) }

      it "re-enqueues with shorter interval without calling user_info" do
        job.perform(gitlab_integration.id)

        expect(described_class).to have_received(:perform_in).with(3.hours, gitlab_integration.id)
      end
    end

    context "when gitlab integration not found" do
      it "exits early without error" do
        expect { job.perform("non-existent-id") }.not_to raise_error
        expect(described_class).not_to have_received(:perform_in)
      end
    end

    context "when errors occur" do
      let(:token_error) { Installations::Error.new("Token expired", reason: :token_refresh_failure) }
      let(:api_error) { Installations::Error.new("API error", reason: :api_error) }
      let(:unexpected_error) { StandardError.new("Unexpected error") }

      it "handles token refresh failure by logging warning and not rescheduling" do
        allow_any_instance_of(GitlabIntegration).to receive(:user_info).and_raise(token_error)

        job.perform(gitlab_integration.id)

        expect(job).to have_received(:elog).with(token_error, level: :warn)
        expect(described_class).not_to have_received(:perform_in)
      end

      it "handles API errors by logging error and rescheduling for 1 hour" do
        allow_any_instance_of(GitlabIntegration).to receive(:user_info).and_raise(api_error)

        job.perform(gitlab_integration.id)

        expect(job).to have_received(:elog).with(api_error, level: :error)
        expect(described_class).to have_received(:perform_in).with(1.hour, gitlab_integration.id)
      end

      it "handles unexpected errors by logging error and rescheduling for 1 hour" do
        allow_any_instance_of(GitlabIntegration).to receive(:user_info).and_raise(unexpected_error)

        job.perform(gitlab_integration.id)

        expect(job).to have_received(:elog).with(unexpected_error, level: :error)
        expect(described_class).to have_received(:perform_in).with(1.hour, gitlab_integration.id)
      end
    end
  end

  describe "#re_enqueue" do
    it "schedules job with specified wait time" do
      job.re_enqueue("test-id", 2.hours)
      expect(described_class).to have_received(:perform_in).with(2.hours, "test-id")
    end
  end

  describe "after_create_commit callback" do
    it "schedules keepalive job when GitlabIntegration is created" do
      new_gitlab_integration = build(:gitlab_integration,
        :without_callbacks_and_validations,
        oauth_access_token: "test_token",
        oauth_refresh_token: "test_refresh_token")

      new_gitlab_integration.save!

      expect(described_class).to have_received(:perform_in).with(6.hours, new_gitlab_integration.id)
    end
  end
end
