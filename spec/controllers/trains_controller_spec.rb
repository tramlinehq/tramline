require "rails_helper"

describe TrainsController do
  let(:app) { create(:app, :android) }
  let(:organization) { app.organization }
  let(:user) { organization.owner }
  let(:channel) { {"id" => "C123", "name" => "releases", "is_private" => false} }
  let(:train) { create(:train, app:, notification_channel: channel) }

  let(:notification_provider) { instance_double(SlackIntegration) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(App).to receive(:ready?).and_return(true)
    allow_any_instance_of(App).to receive(:notifications_set_up?).and_return(true)
    allow_any_instance_of(App).to receive(:notification_provider).and_return(notification_provider)
    allow(notification_provider).to receive(:channels).and_return([{id: "C123", name: "releases", is_private: false}])
  end

  describe "PATCH #update notification_channel" do
    it "keeps the existing channel when notifications stay enabled but the channel submits blank" do
      expect {
        patch :update, params: {app_id: app.id, id: train.id, train: {notifications_enabled: "true", notification_channel: ""}}
      }.not_to change { train.reload.notification_channel }

      expect(train.reload.notification_channel).to eq(channel)
    end

    it "updates the channel when a new one is submitted" do
      new_channel = {"id" => "C999", "name" => "hotfixes", "is_private" => false}

      patch :update, params: {
        app_id: app.id,
        id: train.id,
        train: {notifications_enabled: "true", notification_channel: new_channel.to_json}
      }

      expect(train.reload.notification_channel).to eq(new_channel)
    end

    it "clears the channel only when notifications are explicitly disabled" do
      patch :update, params: {app_id: app.id, id: train.id, train: {notifications_enabled: "false"}}

      expect(train.reload.notification_channel).to be_nil
    end
  end

  describe "#set_notification_channels option injection" do
    before do
      controller.instance_variable_set(:@app, app)
      controller.instance_variable_set(:@train, train)
    end

    context "when the configured channel is missing from the fetched channel list" do
      before do
        # simulate the stored channel being absent from Slack's list (archived/truncated fetch)
        allow(notification_provider).to receive(:channels).and_return([{id: "C555", name: "other", is_private: false}])
      end

      it "appends the configured channel as a selectable option" do
        controller.send(:set_notification_channels)

        channels = controller.instance_variable_get(:@notification_channels)
        expect(channels.pluck(:id)).to include("C123")
        expect(channels).to include({id: "C123", name: "releases", is_private: false})
      end
    end

    context "when the configured channel is already in the fetched channel list" do
      it "does not duplicate it" do
        controller.send(:set_notification_channels)

        channels = controller.instance_variable_get(:@notification_channels)
        expect(channels.count { |c| c[:id] == "C123" }).to eq(1)
      end
    end
  end
end
