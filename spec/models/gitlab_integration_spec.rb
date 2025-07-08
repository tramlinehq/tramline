require "rails_helper"

RSpec.describe GitlabIntegration do
  let(:app) { create(:app) }
  let(:integration) { create(:integration, integrable: app) }
  let(:gitlab_integration) { create(:gitlab_integration, :without_callbacks_and_validations, integration: integration) }
  let(:app_config) { app.config }
  let(:installation) { double("installation") }

  before do
    allow(gitlab_integration).to receive(:app_config).and_return(app_config)
    allow(gitlab_integration).to receive(:installation).and_return(installation)
    allow(installation).to receive(:get_file_content)
    allow(installation).to receive(:update_file!)
    allow(installation).to receive(:run_pipeline!)
    allow(installation).to receive(:cancel_pipeline!)
    allow(installation).to receive(:retry_pipeline!)
    allow(installation).to receive(:get_pipeline)
    allow(installation).to receive(:create_tag!)
    allow(installation).to receive(:cherry_pick_pr)
    allow(installation).to receive(:enable_auto_merge)
  end

  describe "#get_file_content" do
    it "calls the GitLab API to get file content" do
      gitlab_integration.get_file_content("main", "path/to/file.txt")
      expect(installation).to have_received(:get_file_content).with(app_config.code_repository_name, "main", "path/to/file.txt")
    end
  end

  describe "#update_file!" do
    it "calls the GitLab API to update a file" do
      gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message")
      expect(installation).to have_received(:update_file!).with(app_config.code_repository_name, "main", "path/to/file.txt", "new content", "commit message", author_name: nil, author_email: nil)
    end
  end

  describe "#trigger_workflow_run!" do
    it "calls the GitLab API to trigger a pipeline" do
      gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"})
      expect(installation).to have_received(:run_pipeline!).with(app_config.code_repository_name, "main", {key: "value"}, GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
    end
  end

  describe "#cancel_workflow_run!" do
    it "calls the GitLab API to cancel a pipeline" do
      gitlab_integration.cancel_workflow_run!("123")
      expect(installation).to have_received(:cancel_pipeline!).with(app_config.code_repository_name, "123")
    end
  end

  describe "#retry_workflow_run!" do
    it "calls the GitLab API to retry a pipeline" do
      gitlab_integration.retry_workflow_run!("123")
      expect(installation).to have_received(:retry_pipeline!).with(app_config.code_repository_name, "123")
    end
  end

  describe "#get_workflow_run" do
    it "calls the GitLab API to get a pipeline" do
      gitlab_integration.get_workflow_run("123")
      expect(installation).to have_received(:get_pipeline).with(app_config.code_repository_name, "123", GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
    end
  end

  describe "#create_tag!" do
    it "calls the GitLab API to create a tag" do
      gitlab_integration.create_tag!("v1.0.0", "abcdef")
      expect(installation).to have_received(:create_tag!).with(app_config.code_repository_name, "v1.0.0", "abcdef")
    end
  end

  describe "#create_patch_pr!" do
    it "calls the GitLab API to cherry pick a commit" do
      gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title")
      expect(installation).to have_received(:cherry_pick_pr).with(app_config.code_repository_name, "main", "patch-branch", "abcdef", "PR Title", GitlabIntegration::PR_TRANSFORMATIONS)
    end
  end

  describe "#enable_auto_merge!" do
    it "calls the GitLab API to enable auto merge" do
      gitlab_integration.enable_auto_merge!(123)
      expect(installation).to have_received(:enable_auto_merge).with(app_config.code_repository_name, 123)
    end
  end

  describe "#bot_name" do
    it "returns the bot name" do
      expect(gitlab_integration.bot_name).to eq("gitlab-bot")
    end
  end
end
