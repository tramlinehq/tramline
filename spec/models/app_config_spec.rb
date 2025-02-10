# frozen_string_literal: true

require "rails_helper"

describe AppConfig do
  describe "#jira_release_filters" do
    let(:app) { create(:app, :android) }
    let(:sample_release_label) { "release-1.0" }
    let(:sample_version) { "v1.0.0" }

    context "with invalid filter type" do
      let(:filters) { [{"type" => "invalid", "value" => "test"}] }

      before do
        app.config[:jira_config] = {"release_filters" => filters}
        app.config.valid?
      end

      it "is invalid" do
        expect(app.config).not_to be_valid
        expect(app.config.errors[:jira_config]).to include("release filters must contain valid type and value")
      end
    end

    context "with empty filter value" do
      let(:filters) { [{"type" => "label", "value" => ""}] }

      before do
        app.config[:jira_config] = {"release_filters" => filters}
        app.config.valid?
      end

      it "is invalid" do
        expect(app.config).not_to be_valid
        expect(app.config.errors[:jira_config]).to include("release filters must contain valid type and value")
      end
    end

    context "with valid filters" do
      let(:filters) do
        [
          {"type" => "label", "value" => sample_release_label},
          {"type" => "fix_version", "value" => sample_version}
        ]
      end

      before do
        app.config[:jira_config] = {"release_filters" => filters}
        app.config.valid?
      end

      it "is valid" do
        expect(app.config).to be_valid
      end
    end
  end
end
