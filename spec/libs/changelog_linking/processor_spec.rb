require "rails_helper"

RSpec.describe ChangelogLinking::Processor do
  let(:app) { create(:app, platform: :android) }
  let(:processor) { described_class.new(app) }

  describe "#process" do
    context "with Linear integration" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "links Linear tickets correctly" do
        messages = ["VOICE-330: Fix null location in debug recording analytics event (#2591)"]
        result = processor.process(messages)

        expect(result).to be_an(Array)
        parsed_result = JSON.parse(result.first)
        expect(parsed_result).to include("linear.app/dummy/issue/VOICE-330")
        expect(parsed_result).to include("github.com/tramlinehq/ueno/pull/2591")
      end

      it "handles tickets in brackets" do
        messages = ["[IFNO-4936] Modify order payload fix (#15624)"]
        result = processor.process(messages)

        parsed_result = JSON.parse(result.first)
        expect(parsed_result).to include("• [<https://linear.app/dummy/issue/IFNO-4936%7CIFNO-4936>] Modify order payload fix (<https://github.com/tramlinehq/ueno/pull/15624%7C#15624>)")
      end

      it "handles multiple tickets in one message" do
        messages = ["[IE-4945][IE-4946] Modify order payload fix (#15624)"]
        result = processor.process(messages)

        parsed_result = JSON.parse(result.first)
        expect(parsed_result).to include("IE-4945")
        expect(parsed_result).to include("IE-4946")
      end
    end

    context "with Jira integration" do
      before do
        create(:integration, category: "project_management", providable: create(:jira_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "links Jira tickets correctly" do
        messages = ["CX-654: Fix nesting flows during review"]
        result = processor.process(messages)

        parsed_result = JSON.parse(result.first)
        expect(parsed_result).to include("atlassian.net/browse/CX-654")
      end
    end

    context "with GitHub integration" do
      before do
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "links GitHub PRs correctly" do
        messages = ["Bump version to X.Y.Z (#2608)"]
        result = processor.process(messages)

        parsed_result = JSON.parse(result.first)
        expect(parsed_result).to include("github.com/tramlinehq/ueno/pull/2608")
      end
    end

    context "when grouping and sorting" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "groups by ticket prefix and sorts alphabetically" do
        messages = [
          "VOICE-330: Fix voice issue",
          "CX-654: Fix customer experience",
          "VOICE-331: Another voice fix",
          "Bump version (#123)"
        ]

        result = processor.process(messages)
        content = JSON.parse(result.first)

        expect(content).to match(/General.*CX.*VOICE/m)
      end
    end

    context "when handling character limits" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "splits long content into multiple chunks" do
        long_messages = Array.new(100) { |i| "VOICE-#{i}: Very long commit message that will exceed the character limit" }
        result = processor.process(long_messages)

        expect(result.length).to be > 1
        result.each do |chunk|
          expect(chunk.length).to be <= 3500
        end
      end
    end
  end
end
