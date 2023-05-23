require "rails_helper"

describe SlackIntegration do
  describe "#populate_channels!" do
    let(:integration) { create(:integration, :with_slack) }
    let(:slack_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Slack::Api) }

    before do
      allow(slack_integration).to receive(:installation).and_return(api_double)
    end

    it "fetches channels from slack API" do
      allow(api_double).to receive(:list_channels)
        .with(described_class::CHANNELS_TRANSFORMATIONS, nil)
        .and_return({channels: [], next_cursor: nil})

      slack_integration.populate_channels!

      expect(api_double).to have_received(:list_channels).with(described_class::CHANNELS_TRANSFORMATIONS, nil).once
    end

    it "fetches all pages of channels from slack API" do
      allow(api_double).to receive(:list_channels)
        .with(described_class::CHANNELS_TRANSFORMATIONS, anything)
        .and_return({channels: ["channel-1", "channel-2"], next_cursor: "next_page"},
          {channels: ["channel-3"], next_cursor: ""})

      slack_integration.populate_channels!

      expect(api_double).to have_received(:list_channels).with(described_class::CHANNELS_TRANSFORMATIONS, anything).twice
    end

    it "stores the channels in the cache" do
      allow(api_double).to receive(:list_channels)
        .with(described_class::CHANNELS_TRANSFORMATIONS, anything)
        .and_return({channels: ["channel-1", "channel-2"], next_cursor: "next_page"},
          {channels: ["channel-3"], next_cursor: ""})

      expect(Rails.cache.read(slack_integration.channels_cache_key)).to be_nil
      slack_integration.populate_channels!
      expect(Rails.cache.read(slack_integration.channels_cache_key)).to contain_exactly("channel-1", "channel-2", "channel-3")
    end
  end
end
