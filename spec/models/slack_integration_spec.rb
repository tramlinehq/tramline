require "rails_helper"

describe SlackIntegration do
  describe "#populate_channels!" do
    let(:integration) { create(:integration, :with_slack) }
    let(:slack_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Slack::Api) }

    before do
      allow(slack_integration).to receive(:installation).and_return(api_double)
      # Don't actually wait out the inter-page throttle in specs.
      allow(slack_integration).to receive(:sleep)
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

    it "throttles between fetched pages" do
      allow(api_double).to receive(:list_channels)
        .with(described_class::CHANNELS_TRANSFORMATIONS, anything)
        .and_return({channels: ["channel-1"], next_cursor: "next_page"},
          {channels: ["channel-2"], next_cursor: ""})

      slack_integration.populate_channels!

      # Two pages → one inter-page sleep (never after the final page).
      expect(slack_integration).to have_received(:sleep).once
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

  describe "#channels" do
    let(:integration) { create(:integration, :with_slack) }
    let(:slack_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Slack::Api) }

    before do
      allow(slack_integration).to receive(:installation).and_return(api_double)
      allow(slack_integration).to receive(:sleep)
      allow(slack_integration).to receive(:fetch_channels) # don't enqueue the real job
      Rails.cache.delete(slack_integration.channels_cache_key)
    end

    it "returns the cached list without hitting the API when warm" do
      allow(api_double).to receive(:list_channels)
      Rails.cache.write(slack_integration.channels_cache_key,
        [{id: "C9", name: "warm", is_private: false, member_count: 1}], expires_in: 1.minute)

      expect(slack_integration.channels).to contain_exactly({id: "C9", name: "warm", is_private: false})
      expect(api_double).not_to have_received(:list_channels)
      expect(slack_integration).not_to have_received(:fetch_channels)
    end

    it "fetches only the inline budget of pages and parks the rest on a job" do
      call = 0
      allow(api_double).to receive(:list_channels) do |_transforms, _cursor|
        call += 1
        {channels: [{id: "C#{call}", name: "c#{call}", is_private: false}], next_cursor: "cursor-#{call}"}
      end

      result = slack_integration.channels

      expect(api_double).to have_received(:list_channels).exactly(described_class::CHANNELS_SYNC_PAGE_LIMIT).times
      expect(result.size).to eq(described_class::CHANNELS_SYNC_PAGE_LIMIT)
      expect(slack_integration).to have_received(:fetch_channels)
    end

    it "completes inline and spawns no job when the workspace fits the budget" do
      allow(api_double).to receive(:list_channels) do |_transforms, cursor|
        if cursor.nil?
          {channels: [{id: "C1", name: "c1", is_private: false}], next_cursor: "c-1"}
        else
          {channels: [{id: "C2", name: "c2", is_private: false}], next_cursor: ""}
        end
      end

      result = slack_integration.channels

      expect(result).to contain_exactly({id: "C1", name: "c1", is_private: false}, {id: "C2", name: "c2", is_private: false})
      expect(slack_integration).not_to have_received(:fetch_channels)
      expect(Rails.cache.read(slack_integration.channels_cache_key)).to be_present
    end

    it "returns and caches the sliced channels on success" do
      allow(api_double).to receive(:list_channels)
        .and_return({channels: [{id: "C1", name: "general", is_private: false, member_count: 4}], next_cursor: ""})

      expect(slack_integration.channels).to contain_exactly({id: "C1", name: "general", is_private: false})
      expect(Rails.cache.read(slack_integration.channels_cache_key)).to be_present
    end

    context "when a page of the channel fetch fails midway" do
      before do
        # First page returns; the next cursor raises. (A chained
        # and_return(...).and_raise(...) doesn't sequence in RSpec — the raise
        # overrides — so drive it off the cursor instead.)
        allow(api_double).to receive(:list_channels) do |_transforms, cursor|
          if cursor.nil?
            {channels: [{id: "C1", name: "general", is_private: false}], next_cursor: "next_page"}
          else
            raise Installations::Error.new("boom", reason: "ratelimited")
          end
        end
      end

      it "surfaces the pages fetched so far instead of raising" do
        expect(slack_integration.channels).to contain_exactly({id: "C1", name: "general", is_private: false})
      end

      it "publishes the partial progress so the UI isn't empty mid-walk" do
        slack_integration.channels
        expect(Rails.cache.read(slack_integration.channels_cache_key))
          .to contain_exactly({id: "C1", name: "general", is_private: false})
      end

      it "parks a job to finish the walk asynchronously" do
        slack_integration.channels
        expect(slack_integration).to have_received(:fetch_channels)
      end

      it "caches the partial with a short TTL, not the full CACHE_EXPIRY" do
        allow(Rails.cache).to receive(:write).and_call_original

        slack_integration.channels

        expect(Rails.cache).to have_received(:write)
          .with(slack_integration.channels_cache_key, anything,
            hash_including(expires_in: described_class::CHANNELS_PARTIAL_CACHE_EXPIRY))
        expect(Rails.cache).not_to have_received(:write)
          .with(slack_integration.channels_cache_key, anything,
            hash_including(expires_in: described_class::CACHE_EXPIRY))
      end
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
      params = {diff_changelog: changelog}
      slack_integration.notify_with_threaded_changelog!(channel, "some message", "notif_type", params, changelog_key: :diff_changelog, changelog_partitions: 5, header_affix: "affix")

      changelog_part2 = changelog[5, 5]
      changelog_part3 = changelog[10, 5]
      changelog_part4 = changelog[15, 5]

      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part2, params, header_affix: "affix (2/4)", continuation: true)
      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part3, params, header_affix: "affix (3/4)", continuation: true)
      expect(slack_integration).to have_received(:notify_changelog!).with(channel[:id], "some message", thread_id, changelog_part4, params, header_affix: "affix (4/4)", continuation: true)
    end
  end
end
