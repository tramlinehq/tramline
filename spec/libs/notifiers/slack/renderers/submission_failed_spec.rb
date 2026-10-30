require "rails_helper"

describe Notifiers::Slack::Renderers::SubmissionFailed do
  let(:base_params) do
    {
      app_name: "MyApp",
      app_platform: "ios",
      platform_public_img: "https://storage.googleapis.com/tramline-public-assets/ios.png",
      train_name: "Release Train",
      release_version: "1.2.3",
      build_number: "456",
      submission_channel: "App Store",
      commit_url: "https://github.com/org/repo/commit/abc1234",
      commit_sha: "abc1234",
      submission_requires_manual_action: false,
      user_content: nil
    }
  end

  describe ".render_json" do
    context "when the failure reason has newlines and quotes" do
      let(:failure_reason) do
        "The provided entity is missing a required attribute\nYou must provide a value for \"socialMedia\""
      end

      it "renders valid blocks with the failure reason intact" do
        result = described_class.render_json(**base_params, submission_failure_reason: failure_reason)

        error_block = result[:blocks].find { |b| b.dig("text", "text")&.start_with?("*Error:*") }
        expect(error_block.dig("text", "text")).to eq("*Error:* ```#{failure_reason}```")
      end
    end

    context "when there is no failure reason" do
      it "omits the error block" do
        result = described_class.render_json(**base_params, submission_failure_reason: nil)

        expect(result[:blocks].filter_map { |b| b.dig("text", "text") }).not_to include(a_string_starting_with("*Error:*"))
      end
    end
  end
end
