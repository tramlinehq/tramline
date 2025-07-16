require "rails_helper"

RSpec.describe ChangelogLinking::Slack do
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
        expect(result.first).to include("linear.app/dummy/issue/VOICE-330")
        expect(result.first).to include("github.com/tramlinehq/ueno/pull/2591")
      end

      it "handles tickets in brackets" do
        messages = ["[IFNO-4936] Modify order payload fix (#15624)"]
        result = processor.process(messages)
        
        expect(result.first).to include("• [<https://linear.app/dummy/issue/IFNO-4936%7CIFNO-4936>] Modify order payload fix (<https://github.com/tramlinehq/ueno/pull/15624%7C#15624>)")
      end

      it "handles multiple tickets in one message" do
        messages = ["[IE-4945][IE-4946] Modify order payload fix (#15624)"]
        result = processor.process(messages)
        
        expect(result.first).to include("IE-4945")
        expect(result.first).to include("IE-4946")
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
        
        expect(result.first).to include("atlassian.net/browse/CX-654")
      end
    end

    context "with GitHub integration" do
      before do
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "links GitHub PRs correctly" do
        messages = ["Bump version to X.Y.Z (#2608)"]
        result = processor.process(messages)
        
        expect(result.first).to include("github.com/tramlinehq/ueno/pull/2608")
      end
    end

    context "when processing individual lines" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "processes each line individually without grouping" do
        messages = [
          "CX-123: Fix bug",
          "VOICE-456: Add feature",
          "Bump version (#123)"
        ]
        
        result = processor.process(messages)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
        expect(result[0]).to include("CX-123")
        expect(result[1]).to include("VOICE-456")
        expect(result[2]).to include("Bump version")
      end

      it "handles messages without tickets or PRs" do
        messages = ["Simple commit message without any links"]
        result = processor.process(messages)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first).to eq("• Simple commit message without any links")
      end
    end
  end
end
