# frozen_string_literal: true

require "rails_helper"

describe GithubIntegration do
  describe "#trigger_workflow_run!" do
    let(:integration) { build(:github_integration) }
    let(:installation) { instance_double(Installations::Github::Api) }
    let(:run_id) { 45083872442 }
    let(:not_found) { Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Not Found"}.to_json)) }
    let(:html_url) { "https://github.com/tramline/repo/actions/runs/#{run_id}" }
    let(:run) { {id: run_id, html_url:, run_number: 5} }

    before do
      allow(integration).to receive_messages(installation:, sleep: nil)
      allow(installation).to receive(:run_workflow!).and_return({id: run_id, html_url:})
    end

    it "returns the dispatched run's metadata" do
      allow(installation).to receive(:get_workflow_run).and_return(run)

      result = integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {})

      expect(result).to include("ci_ref" => run_id, "unique_number" => 5)
    end

    it "retries the lookup when GitHub does not have the dispatched run yet" do
      calls = 0
      allow(installation).to receive(:get_workflow_run) do
        calls += 1
        raise not_found if calls == 1
        run
      end

      result = integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {})

      expect(result).to include("ci_ref" => run_id, "unique_number" => 5)
      expect(installation).to have_received(:get_workflow_run).twice
    end

    it "falls back to what the dispatch returned when the lookup keeps failing" do
      allow(installation).to receive(:get_workflow_run).and_raise(not_found)

      result = integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {})

      expect(result).to eq(
        "ci_ref" => run_id,
        "ci_link" => html_url,
        "number" => nil,
        "unique_number" => nil
      )
      expect(installation).to have_received(:get_workflow_run).exactly(described_class::DISPATCHED_RUN_LOOKUP_ATTEMPTS).times
    end

    it "falls back without waiting when the lookup fails for any other reason" do
      allow(installation).to receive(:get_workflow_run).and_raise(Octokit::InternalServerError)

      result = integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {})

      expect(result).to include("ci_ref" => run_id, "ci_link" => html_url)
      expect(installation).to have_received(:get_workflow_run).once
      expect(integration).not_to have_received(:sleep)
    end
  end
end
