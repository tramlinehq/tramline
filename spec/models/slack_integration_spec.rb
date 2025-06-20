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

  describe "#create_channel" do
    let(:integration) { create(:integration, :with_slack) }
    let(:slack_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Slack::Api) }
    let(:channel_name) { Faker::Lorem.word }

    before do
      allow(slack_integration).to receive(:installation).and_return(api_double)
      allow(api_double).to receive(:create_channel)
    end

    it "creates the channel with the name" do
      slack_integration.create_channel!(channel_name)
      expect(api_double).to have_received(:create_channel).with(SlackIntegration::CREATE_CHANNEL_TRANSFORMATIONS, channel_name)
    end

    context "when slack api raises name_taken error" do
      before do
        allow(api_double).to receive(:create_channel).and_raise(Installations::Error.new("Name taken error", reason: "name_taken"))
      end

      it "attempts to create channel again with an appended name" do
        slack_integration.create_channel!(channel_name)
        expect(api_double).to have_received(:create_channel).with(SlackIntegration::CREATE_CHANNEL_TRANSFORMATIONS, channel_name).once
        expect(api_double).to have_received(:create_channel).with(SlackIntegration::CREATE_CHANNEL_TRANSFORMATIONS, "#{channel_name}_1").once
        expect(api_double).to have_received(:create_channel).with(SlackIntegration::CREATE_CHANNEL_TRANSFORMATIONS, "#{channel_name}_2").once
      end

      it "returns nil when no channel is created" do
        expect(slack_integration.create_channel!(channel_name)).to be_nil
      end
    end
  end

  describe "#notify_with_threaded_changelog!" do
    let(:integration) { create(:integration, :with_slack) }
    let(:slack_integration) { integration.providable }

    let(:thread_id) { Faker::Number.number(digits: 10).to_s }
    let(:changelog) { Array.new(20) { Faker::Lorem.sentence } }
    let(:first_part_of_changelog) { changelog[0, 5] }
    let(:channel) { {id: Faker::Alphanumeric.alphanumeric(number: 10)}.with_indifferent_access }

    before do
      allow(slack_integration).to receive(:notify!).and_return(thread_id)
      allow(slack_integration).to receive(:notify_changelog!)
    end

    it "notifies with the first part of the changelog" do
      slack_integration.notify_with_threaded_changelog!(channel, "some message", "notif_type", {diff_changelog: changelog}, changelog_key: :diff_changelog, changelog_partitions: 5, header_affix: "affix")
      expect(slack_integration).to have_received(:notify!).with(channel[:id], "some message", "notif_type", {diff_changelog: changelog, changelog: {first_part: first_part_of_changelog, total_parts: 4, header_affix: "affix"}})
    end

    it "notifies rest of the parts of the changelog" do
      slack_integration.notify_with_threaded_changelog!(channel, "some message", "notif_type", {diff_changelog: changelog}, changelog_key: :diff_changelog, changelog_partitions: 5, header_affix: "affix")

      changelog_part2 = changelog[5, 5]
      changelog_part3 = changelog[10, 5]
      changelog_part4 = changelog[15, 5]

      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part2, header_affix: "affix (2/4)", continuation: true)
      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part3, header_affix: "affix (3/4)", continuation: true)
      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part4, header_affix: "affix (4/4)", continuation: true)
    end
  end
end
