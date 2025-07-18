require "rails_helper"

describe Notifiers::Slack::Changelogs::Linker do
  let(:app) { create(:app, platform: :android) }
  let(:processor) { described_class.new(app) }

  describe "#process" do
    context "with Linear integration" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "returns correct number of elements for messages with tickets and PRs" do
        message = "VOICE-330: Fix null location in debug recording analytics event (#2591)"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(4) # ticket link, text, PR link, text
      end

      it "correctly links Linear tickets" do
        message = "VOICE-330: Fix null location in debug recording analytics event (#2591)"
        result = processor.process(message)

        ticket_element = result[0]
        expect(ticket_element["type"]).to eq("link")
        expect(ticket_element["text"]).to eq("VOICE-330")
        expect(ticket_element["url"]).to include("linear.app")
      end

      it "correctly links GitHub PRs" do
        message = "VOICE-330: Fix null location in debug recording analytics event (#2591)"
        result = processor.process(message)

        pr_element = result[2]
        expect(pr_element["type"]).to eq("link")
        expect(pr_element["text"]).to eq("#2591")
        expect(pr_element["url"]).to include("github.com")
      end

      it "preserves text content between links" do
        message = "VOICE-330: Fix null location in debug recording analytics event (#2591)"
        result = processor.process(message)

        text_element = result[1]
        expect(text_element["type"]).to eq("text")
        expect(text_element["text"]).to eq(": Fix null location in debug recording analytics event (")

        closing_text_element = result[3]
        expect(closing_text_element["type"]).to eq("text")
        expect(closing_text_element["text"]).to eq(")")
      end

      it "returns plain text elements for messages without links" do
        message = "Simple commit message without any links"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        text_element = result[0]
        expect(text_element["type"]).to eq("text")
        expect(text_element["text"]).to eq("Simple commit message without any links")
      end
    end

    context "with Jira integration" do
      before do
        create(:integration, category: "project_management", providable: create(:jira_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "returns correct number of elements for Jira tickets" do
        message = "CX-654: Fix nesting flows during review"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2) # ticket link, text
      end

      it "correctly links Jira tickets" do
        message = "CX-654: Fix nesting flows during review"
        result = processor.process(message)

        ticket_element = result[0]
        expect(ticket_element["type"]).to eq("link")
        expect(ticket_element["text"]).to eq("CX-654")
        expect(ticket_element["url"]).to include("atlassian.net")
      end

      it "preserves remaining text after Jira tickets" do
        message = "CX-654: Fix nesting flows during review"
        result = processor.process(message)

        text_element = result[1]
        expect(text_element["type"]).to eq("text")
        expect(text_element["text"]).to eq(": Fix nesting flows during review")
      end
    end

    context "with GitHub integration" do
      before do
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "returns correct number of elements for GitHub PRs" do
        message = "Bump version to X.Y.Z (#2608)"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(3) # text, PR link, text
      end

      it "correctly links GitHub PRs" do
        message = "Bump version to X.Y.Z (#2608)"
        result = processor.process(message)

        pr_element = result[1]
        expect(pr_element["type"]).to eq("link")
        expect(pr_element["text"]).to eq("#2608")
        expect(pr_element["url"]).to include("github.com")
      end

      it "preserves text around GitHub PRs" do
        message = "Bump version to X.Y.Z (#2608)"
        result = processor.process(message)

        text_element = result[0]
        expect(text_element["type"]).to eq("text")
        expect(text_element["text"]).to eq("Bump version to X.Y.Z (")

        closing_text = result[2]
        expect(closing_text["type"]).to eq("text")
        expect(closing_text["text"]).to eq(")")
      end
    end

    context "with tickets in brackets" do
      before do
        create(:integration, category: "project_management", providable: create(:linear_integration), integrable: app)
        create(:integration, category: "version_control", providable: create(:github_integration), integrable: app)
      end

      it "returns correct number of elements for tickets in brackets" do
        message = "[IFNO-4936] Modify order payload fix (#15624)"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(5) # text, ticket link, text, PR link, text
      end

      it "correctly links tickets in brackets" do
        message = "[IFNO-4936] Modify order payload fix (#15624)"
        result = processor.process(message)

        expect(result[1]["type"]).to eq("link")
        expect(result[1]["text"]).to eq("IFNO-4936")
        expect(result[1]["url"]).to include("linear.app")
      end

      it "preserves bracket formatting" do
        message = "[IFNO-4936] Modify order payload fix (#15624)"
        result = processor.process(message)

        expect(result[0]["type"]).to eq("text")
        expect(result[0]["text"]).to eq("[")
        expect(result[2]["type"]).to eq("text")
        expect(result[2]["text"]).to eq("] Modify order payload fix (")
      end

      it "handles PRs in bracketed messages" do
        message = "[IFNO-4936] Modify order payload fix (#15624)"
        result = processor.process(message)

        expect(result[3]["type"]).to eq("link")
        expect(result[3]["text"]).to eq("#15624")
        expect(result[3]["url"]).to include("github.com")
      end

      it "returns correct number of elements for multiple tickets" do
        message = "[IE-4945][IE-4946] Modify order payload fix (#15624)"
        result = processor.process(message)

        expect(result).to be_an(Array)
        expect(result.length).to eq(7) # text, ticket1, text, ticket2, text, PR, text
      end

      it "correctly links multiple tickets" do
        message = "[IE-4945][IE-4946] Modify order payload fix (#15624)"
        result = processor.process(message)

        ticket_elements = result.select { |elem| elem["type"] == "link" && elem["text"].include?("IE-") }
        expect(ticket_elements.length).to eq(2)
        expect(ticket_elements.pluck("text")).to include("IE-4945", "IE-4946")
      end

      it "handles PRs alongside multiple tickets" do
        message = "[IE-4945][IE-4946] Modify order payload fix (#15624)"
        result = processor.process(message)

        pr_elements = result.select { |elem| elem["type"] == "link" && elem["text"].include?("#") }
        expect(pr_elements.length).to eq(1)
        expect(pr_elements.first["text"]).to eq("#15624")
      end
    end

    context "with empty or blank messages" do
      it "returns empty array for blank message" do
        result = processor.process("")
        expect(result).to eq([])
      end

      it "returns empty array for nil message" do
        result = processor.process(nil)
        expect(result).to eq([])
      end

      it "returns empty array for whitespace-only message" do
        result = processor.process("   ")
        expect(result).to eq([])
      end
    end
  end
end
