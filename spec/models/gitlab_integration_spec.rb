require "rails_helper"

describe GitlabIntegration do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, integrable: app) }
  let(:gitlab_integration) { create(:gitlab_integration, :without_callbacks_and_validations, integration: integration) }
  let(:app_config) { app.config }
  let(:installation) { instance_double(Installations::Gitlab::Api) }

  before do
    allow(gitlab_integration).to receive_messages(app_config: app_config, installation: installation)
  end

  describe "#create_release!" do
    it "calls the GitLab API to create a release" do
      allow(installation).to receive(:create_release!).and_return({"tag_name" => "v1.0.0"})
      result = gitlab_integration.create_release!("v1.0.0", "main", anything, "Release notes")
      expect(installation).to have_received(:create_release!).with(app_config.code_repository_name, "v1.0.0", "main", "Release notes")
      expect(result).to eq({"tag_name" => "v1.0.0"})
    end

    context "when release creation fails" do
      it "raises an error" do
        allow(installation).to receive(:create_release!).and_raise(Installations::Gitlab::Error.new({"message" => "Release already exists"}))
        expect { gitlab_integration.create_release!("v1.0.0", "main", anything, "Release notes") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#get_file_content" do
    it "calls the GitLab API to get file content" do
      allow(installation).to receive(:get_file_content).and_return("file content")
      result = gitlab_integration.get_file_content("main", "path/to/file.txt")
      expect(installation).to have_received(:get_file_content).with(app_config.code_repository_name, "main", "path/to/file.txt")
      expect(result).to eq("file content")
    end

    context "when file doesn't exist" do
      it "returns nil" do
        allow(installation).to receive(:get_file_content).and_return(nil)
        result = gitlab_integration.get_file_content("main", "nonexistent.txt")
        expect(result).to be_nil
      end
    end

    context "when file access fails" do
      it "raises an error" do
        allow(installation).to receive(:get_file_content).and_raise(Installations::Gitlab::Error.new({"message" => "404 File Not Found"}))
        expect { gitlab_integration.get_file_content("main", "protected.txt") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#update_file!" do
    it "calls the GitLab API to update a file" do
      allow(installation).to receive(:update_file!).and_return(true)
      result = gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message")
      expect(installation).to have_received(:update_file!).with(app_config.code_repository_name, "main", "path/to/file.txt", "new content", "commit message", author_name: nil, author_email: nil)
      expect(result).to be true
    end

    context "with author information" do
      it "passes author details to update_file!" do
        allow(installation).to receive(:update_file!).and_return(true)
        gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message", author_name: "Test User", author_email: "test@example.com")
        expect(installation).to have_received(:update_file!).with(app_config.code_repository_name, "main", "path/to/file.txt", "new content", "commit message", author_name: "Test User", author_email: "test@example.com")
      end
    end

    context "when file update fails" do
      it "raises an error" do
        allow(installation).to receive(:update_file!).and_raise(Installations::Gitlab::Error.new({"message" => "File update failed"}))
        expect { gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#trigger_workflow_run!" do
    it "calls the GitLab API to trigger a pipeline" do
      allow(installation).to receive_messages(
        run_pipeline_with_job!: {ci_ref: "123", ci_link: "http://example.com"},
        list_pipeline_jobs: [{id: "job1", name: "ci_cd_channel", status: "success", stage: "test"}],
        trigger_job!: nil
      )
      gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"})
      expect(installation).to have_received(:run_pipeline_with_job!).with(app_config.code_repository_name, "main", {key: "value"}, "ci_cd_channel", nil, GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
    end

    context "with commit SHA" do
      it "passes commit SHA to run_pipeline_with_job!" do
        allow(installation).to receive(:run_pipeline_with_job!).and_return({ci_ref: "123", ci_link: "http://example.com"})
        gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"}, "abc123")
        expect(installation).to have_received(:run_pipeline_with_job!).with(app_config.code_repository_name, "main", {key: "value"}, "ci_cd_channel", "abc123", GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
      end
    end

    context "when pipeline trigger fails" do
      it "raises an error" do
        allow(installation).to receive(:run_pipeline_with_job!).and_raise(Installations::Error.new("Pipeline failed", reason: :workflow_run_not_found))
        expect { gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"}) }.to raise_error(Installations::Error)
      end
    end
  end

  describe "#cancel_workflow_run!" do
    it "calls the GitLab API to cancel a pipeline" do
      allow(installation).to receive(:cancel_job!)
      gitlab_integration.cancel_workflow_run!("123")
      expect(installation).to have_received(:cancel_job!).with(app_config.code_repository_name, "123")
    end
  end

  describe "#retry_workflow_run!" do
    it "calls the GitLab API to retry a pipeline" do
      allow(installation).to receive(:retry_job!)
      gitlab_integration.retry_workflow_run!("123")
      expect(installation).to have_received(:retry_job!).with(app_config.code_repository_name, "123", GitlabIntegration::JOB_RUN_TRANSFORMATIONS)
    end
  end

  describe "#get_workflow_run" do
    it "calls the GitLab API to get a pipeline" do
      allow(installation).to receive(:get_job)
      gitlab_integration.get_workflow_run("123")
      expect(installation).to have_received(:get_job).with(app_config.code_repository_name, "123")
    end
  end

  describe "#create_tag!" do
    it "calls the GitLab API to create a tag" do
      allow(installation).to receive(:create_tag!).and_return({"name" => "v1.0.0"})
      result = gitlab_integration.create_tag!("v1.0.0", "abcdef")
      expect(installation).to have_received(:create_tag!).with(app_config.code_repository_name, "v1.0.0", "abcdef")
      expect(result).to eq({"name" => "v1.0.0"})
    end

    context "when tag already exists" do
      it "raises an error" do
        allow(installation).to receive(:create_tag!).and_raise(Installations::Gitlab::Error.new({"message" => "Tag v1.0.0 already exists"}))
        expect { gitlab_integration.create_tag!("v1.0.0", "abcdef") }.to raise_error(Installations::Gitlab::Error)
      end
    end

    context "when commit SHA is invalid" do
      it "raises an error" do
        allow(installation).to receive(:create_tag!).and_raise(Installations::Gitlab::Error.new({"message" => "Invalid commit SHA"}))
        expect { gitlab_integration.create_tag!("v1.0.0", "invalid_sha") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#create_patch_pr!" do
    it "calls the GitLab API to cherry pick a commit" do
      allow(installation).to receive(:cherry_pick_pr).and_return({})
      gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title")
      expect(installation).to have_received(:cherry_pick_pr).with(app_config.code_repository_name, "main", "abcdef", "patch-branch", "PR Title", "", GitlabIntegration::PR_TRANSFORMATIONS)
    end

    context "with custom description" do
      it "passes description to cherry_pick_pr" do
        allow(installation).to receive(:cherry_pick_pr).and_return({})
        gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title", "Custom description")
        expect(installation).to have_received(:cherry_pick_pr).with(app_config.code_repository_name, "main", "abcdef", "patch-branch", "PR Title", "Custom description", GitlabIntegration::PR_TRANSFORMATIONS)
      end
    end

    context "when cherry-pick fails" do
      it "raises an error" do
        allow(installation).to receive(:cherry_pick_pr).and_raise(Installations::Gitlab::Error.new({"message" => "Cherry-pick failed"}))
        expect { gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#enable_auto_merge!" do
    it "calls the GitLab API to enable auto merge" do
      allow(installation).to receive(:enable_auto_merge).and_return(true)
      result = gitlab_integration.enable_auto_merge!(123)
      expect(installation).to have_received(:enable_auto_merge).with(app_config.code_repository_name, 123)
      expect(result).to be true
    end

    context "when PR is already merged" do
      it "returns early" do
        allow(installation).to receive(:enable_auto_merge).and_return(nil)
        result = gitlab_integration.enable_auto_merge!(123)
        expect(result).to be_nil
      end
    end

    context "when enable auto merge fails" do
      it "raises an error" do
        allow(installation).to receive(:enable_auto_merge).and_raise(Installations::Gitlab::Error.new({"message" => "Cannot enable auto merge"}))
        expect { gitlab_integration.enable_auto_merge!(123) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#bot_name" do
    it "returns the bot name" do
      expect(gitlab_integration.bot_name).to eq("gitlab-bot")
    end
  end
end
