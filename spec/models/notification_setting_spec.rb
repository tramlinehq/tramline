# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationSetting do
  let(:notification_provider) { instance_double(SlackIntegration) }

  before do
    allow_any_instance_of(described_class).to receive(:notification_provider).and_return(notification_provider)
    allow_any_instance_of(App).to receive(:notifications_set_up?).and_return(true)
    allow(notification_provider).to receive(:notify!)
  end

  it "has a valid factory" do
    expect(create(:notification_setting)).to be_valid
  end

  describe "#notify" do
    context "when notifications are not set up on the app" do
      let(:setting) { create(:notification_setting) }

      before do
        allow_any_instance_of(App).to receive(:notifications_set_up?).and_return(false)
      end

      it "does not send notification" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).not_to have_received(:notify!)
      end
    end

    context "when notification is not active" do
      let(:setting) { create(:notification_setting, :inactive) }

      it "does not send notification" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).not_to have_received(:notify!)
      end
    end

    context "when destination is not release specific channel" do
      let(:setting) { create(:notification_setting) }

      it "sends notification to default channels" do
        setting.notify!("Message", {param: "value"})

        setting.notification_channels.each do |channel|
          expect(notification_provider).to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end

    context "when destination is both release specific channel and default channel" do
      let(:setting) { create(:notification_setting, :release_specific) }

      it "sends notification to release specific channel" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).to have_received(:notify!).with(setting.release_specific_channel["id"], any_args)
      end

      it "sends notification to default channels" do
        setting.notify!("Message", {param: "value"})
        setting.notification_channels.each do |channel|
          expect(notification_provider).to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end

    context "when destination is only release specific channel" do
      let(:setting) { create(:notification_setting, :only_release_specific) }

      it "sends notification to release specific channel" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).to have_received(:notify!).with(setting.release_specific_channel["id"], any_args)
      end

      it "does not send notification to default channels" do
        setting.notify!("Message", {param: "value"})
        setting.notification_channels.each do |channel|
          expect(notification_provider).not_to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end
  end
end
