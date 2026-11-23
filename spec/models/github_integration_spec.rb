# frozen_string_literal: true

require "rails_helper"

describe GithubIntegration do
  describe "#trigger_workflow_run!" do
    let(:integration) { build(:github_integration) }
    let(:installation) { instance_double(Installations::Github::Api) }
    let(:run_id) { 45083872442 }
    let(:not_found) { Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Not Found"}.to_json)) }
    let(:run) { {id: run_id, html_url: "https://github.com/tramline/repo/actions/runs/#{run_id}", run_number: 5} }

    before do
      allow(integration).to receive_messages(installation:, sleep: nil)
      allow(installation).to receive(:run_workflow!).and_return(run_id)
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

    it "falls back to the dispatched run id when the lookup keeps failing" do
      allow(installation).to receive(:get_workflow_run).and_raise(not_found)

      result = integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {})

      expect(result).to eq(
        "ci_ref" => run_id,
        "ci_link" => "https://github.com/tramline/repo/actions/runs/#{run_id}",
        "number" => nil,
        "unique_number" => nil
      )
      expect(installation).to have_received(:get_workflow_run).exactly(described_class::DISPATCHED_RUN_LOOKUP_ATTEMPTS).times
    end

    it "does not swallow other lookup errors" do
      error = Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Bad credentials"}.to_json))
      allow(installation).to receive(:get_workflow_run).and_raise(error)

      expect { integration.trigger_workflow_run!("ios-release.yml", "r/2.5.0", {}) }.to raise_error(error)
    end
  end
end
