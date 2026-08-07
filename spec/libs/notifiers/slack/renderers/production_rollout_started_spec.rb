# frozen_string_literal: true

require "rails_helper"

describe Notifiers::Slack::Renderers::ProductionRolloutStarted do
  let(:base_params) do
    {
      app_name: "MyApp",
      app_platform: "android",
      platform_public_img: "https://storage.googleapis.com/tramline-public-assets/android.png",
      vcs_public_icon_img: "https://storage.googleapis.com/tramline-public-assets/github.png",
      train_name: "McDonald's Release",
      release_version: "1.2.3",
      build_number: "456",
      rollout_percentage: "10",
      release_url: "https://tramline.app/releases/1",
      release_branch: "release/1.2.3",
      release_branch_url: "https://github.com/org/repo/tree/release/1.2.3",
      requires_review: true,
      user_content: nil,
      changelog: {
        first_part: ["Fix crash on startup"],
        total_parts: 1,
        header_affix: "Changes in release"
      }
    }
  end

  describe ".render_json" do
    it "returns a hash with a blocks array" do
      result = described_class.render_json(**base_params)
      expect(result).to be_a(Hash)
      expect(result[:blocks]).to be_an(Array).and be_present
    end

    context "when changelog entries contain apostrophes" do
      let(:params) do
        base_params.merge(
          changelog: {
            first_part: ["Fix user's login flow", "App'll now handle retries correctly"],
            total_parts: 1,
            header_affix: "Changes in release"
          }
        )
      end

      it "does not raise JSON::ParserError" do
        expect { described_class.render_json(**params) }.not_to raise_error
      end
    end

    context "when user_content contains apostrophes" do
      let(:params) { base_params.merge(user_content: "The team's release notes: it'll be great!") }

      it "does not raise JSON::ParserError" do
        expect { described_class.render_json(**params) }.not_to raise_error
      end
    end

    context "when requires_review is false (renders requires_review_text with google_unmanaged_publishing_text)" do
      let(:params) { base_params.merge(requires_review: false) }

      it "does not raise JSON::ParserError" do
        # google_unmanaged_publishing_text contains "you'll" which previously broke JSON.parse
        # via escape_javascript producing the invalid JSON escape sequence \'
        expect { described_class.render_json(**params) }.not_to raise_error
      end
    end

    context "when train_name contains apostrophes" do
      let(:params) { base_params.merge(train_name: "McDonald's Release") }

      it "does not raise JSON::ParserError" do
        expect { described_class.render_json(**params) }.not_to raise_error
      end
    end
  end

  describe "#safe_string" do
    subject(:renderer) { described_class.new(**base_params) }

    it "does not escape apostrophes with a backslash" do
      expect(renderer.safe_string("it'll work")).not_to include("\\'")
    end

    it "produces output that embeds as valid JSON in a string value" do
      output = renderer.safe_string("it's the user's app")
      expect { JSON.parse(%({"text": "#{output}"})) }.not_to raise_error
    end

    it "still escapes double quotes for JSON safety" do
      output = renderer.safe_string("user's \"quoted\" value")
      expect(output).to include('\\"')
      expect(output).not_to include("\\'")
      expect { JSON.parse(%({"text": "#{output}"})) }.not_to raise_error
    end

    it "still escapes backslashes for JSON safety" do
      output = renderer.safe_string("user's C:\\Users\\path")
      expect(output).to include("\\\\")
      expect(output).not_to include("\\'")
      expect { JSON.parse(%({"text": "#{output}"})) }.not_to raise_error
    end

    it "still escapes newlines for JSON safety" do
      output = renderer.safe_string("user's notes\nline two")
      expect(output).to include("\\n")
      expect(output).not_to include("\\'")
      expect { JSON.parse(%({"text": "#{output}"})) }.not_to raise_error
    end
  end
end
