require "rails_helper"

describe Installations::Slack::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }

  describe "#list_channels" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/slack/channels.json")) }

    it "returns the transformed list of enabled apps" do
      allow_any_instance_of(described_class).to receive(:execute).with(:get,
        "https://slack.com/api/conversations.list",
        {
          params: {
            limit: 200,
            exclude_archived: true,
            types: "public_channel,private_channel"
          }
        })
        .and_return(payload)
      result = described_class.new(access_token).list_channels(SlackIntegration::LIST_CHANNELS_TRANSFORMATIONS)

      expected_projects = [
        {
          id: "C012AB3CD",
          name: "general",
          description: "This channel is for team-wide communication and announcements. All team members are in this channel.",
          is_private: false,
          member_count: 4
        },
        {
          id: "C061EG9T2",
          name: "random",
          description: "A place for non-work-related flimflam, faffing, hodge-podge or jibber-jabber you'd prefer to keep out of more focused work-related channels.",
          is_private: false,
          member_count: 4
        }
      ]
      expect(result).to contain_exactly(*expected_projects)
    end
  end
end
