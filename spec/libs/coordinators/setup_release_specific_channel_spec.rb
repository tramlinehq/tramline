require "rails_helper"

RSpec.describe Coordinators::SetupReleaseSpecificChannel do
  let(:default_notification_channel) { {id: "ABCD", name: "general", is_private: false} }

  let(:train) { create(:train, :active, notification_channel: default_notification_channel) }
  let(:app) { train.app }

  let(:slack) { instance_double(SlackIntegration) }
  let(:release) { create(:release, train:) }

  let(:release_channel_name) { "release-#{app.name}-#{app.platform}-#{release.release_version}".downcase.gsub(/\W/, "-") }
  let(:slack_response) { {id: Faker::Alphanumeric.alpha(number: 10), name: release_channel_name, is_private: false} }

  before do
    allow(train).to receive(:send_notifications?).and_return(true)
    allow_any_instance_of(App).to receive(:notification_provider).and_return(slack)
    allow(slack).to receive(:create_channel!).and_return(slack_response.as_json)
  end

  context "when train is configured with release specific channels" do
    before do
      train.update(notifications_release_specific_channel_enabled: true)
    end

    it "creates release specific slack channel" do
      described_class.call(release)
      expect(slack).to have_received(:create_channel!).with(release_channel_name)
    end

    it "updates notification channel in release" do
      described_class.call(release)
      expect(release.reload.release_specific_channel_name).to eq(release_channel_name)
      expect(release.release_specific_channel_id).to eq(slack_response[:id])
    end

    it "updates release specific channel in notifications settings in allowed kinds" do
      described_class.call(release)
      notification_channels = train.notification_settings.release_specific_channel_allowed.pluck(:release_specific_channel)
      expect(notification_channels).to all(eq(slack_response.as_json))
    end

    it "updates notification channel to default channel if create channel fails" do
      allow(slack).to receive(:create_channel!).and_return(nil)
      described_class.call(release)
      expect(release.reload.release_specific_channel_name).to eq(default_notification_channel[:name])
    end
  end

  context "when train is not configured with release specific channels" do
    it "does not create slack channel" do
      described_class.call(release)
      expect(slack).not_to have_received(:create_channel!)
    end

    it "does not update notification channel in release" do
      described_class.call(release)
      expect(release.release_specific_channel_id).to be_nil
      expect(release.release_specific_channel_name).to be_nil
    end

    it "does not update notification channel settings" do
      described_class.call(release)
      notification_channels = train.notification_settings.pluck(:release_specific_channel)
      expect(notification_channels).to all(be_nil)
    end
  end
end
